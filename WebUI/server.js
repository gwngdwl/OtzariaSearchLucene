const express = require('express');
const { execFile } = require('child_process');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.static('public'));
app.use(express.json());

// Path to the OtzariaSearch CLI executable
const EXE_PATH = path.join(__dirname, '..', 'publish', 'OtzariaSearch.exe');
const INDEX_PATH = path.join(__dirname, '..', 'search_index');

app.get('/api/search', (req, res) => {
    const query = req.query.q;
    const limit = req.query.limit || 50;
    const book = req.query.book;
    const category = req.query.category;

    if (!query) {
        return res.status(400).json({ error: 'Query parameter "q" is required' });
    }

    // Build arguments
    const args = ['search', query, '--index', INDEX_PATH, '--limit', limit.toString()];
    
    if (book) {
        args.push('--book');
        args.push(book);
    }
    
    if (category) {
        args.push('--category');
        args.push(category);
    }

    console.log(`Executing: ${EXE_PATH} ${args.join(' ')}`);

    // Execute the CLI
    execFile(EXE_PATH, args, { encoding: 'utf8', maxBuffer: 10 * 1024 * 1024 }, (error, stdout, stderr) => {
        if (error && error.code !== 0) { // Some results might have non-zero if there's a CLI issue, but let's check stderr
            console.error('Execution error:', error);
            // We might still have stdout if it didn't completely fail
        }

        if (stderr) {
            console.error('stderr:', stderr);
        }

        // Parse the CLI output
        try {
            const parsedResults = parseOutput(stdout);
            res.json(parsedResults);
        } catch (e) {
            console.error("Parsing error:", e);
            res.status(500).json({ error: "Failed to parse search results", rawOutput: stdout });
        }
    });
});

// Helper function to parse the console output into JSON objects
function parseOutput(output) {
    const lines = output.split('\n').map(l => l.replace('\r', ''));
    
    const result = {
        meta: {
            query: '',
            totalFound: 0,
            elapsedMs: 0
        },
        hits: []
    };

    let i = 0;
    
    // 1. Find metadata (Searching: , X results found (Yms))
    while (i < lines.length) {
        const line = lines[i];
        
        if (line.includes('Searching:')) {
            result.meta.query = line.replace('Searching:', '').replace(/"/g, '').trim();
        }
        else if (line.includes('results found')) {
            // "  5,811 results found (110ms)"
            const match = line.match(/([\d,]+)\s+results found\s+\(([\d,\.]+)ms\)/);
            if (match) {
                result.meta.totalFound = parseInt(match[1].replace(/,/g, ''));
                result.meta.elapsedMs = parseFloat(match[2].replace(/,/g, ''));
            }
        }
        else if (line.startsWith('  [1]')) {
            // Start of results
            break;
        }
        i++;
    }

    // 2. Parse results
    let currentHit = null;

    while (i < lines.length) {
        const line = lines[i];

        if (line.match(/^\s+\[\d+\]\s/)) { // Looks like: "  [1] Book Title | Reference"
            if (currentHit) result.hits.push(currentHit);
            
            currentHit = {
                rank: 0,
                bookTitle: '',
                reference: '',
                category: '',
                snippet: '',
                score: 0
            };

            const rankMatch = line.match(/^\s+\[(\d+)\]\s+(.*)/);
            if (rankMatch) {
                currentHit.rank = parseInt(rankMatch[1]);
                const rest = rankMatch[2];
                const parts = rest.split(' | ');
                currentHit.bookTitle = parts[0].trim();
                currentHit.reference = parts.length > 1 ? parts[1].trim() : '';
            }
        }
        else if (currentHit && line.match(/^\s+\[.*\]$/)) {
            // Category: "      [תלמוד/בבלי]"
            currentHit.category = line.trim().replace('[', '').replace(']', '');
        }
        else if (currentHit && line.includes('Score:')) {
            // Score: "      Score: 4.3073"
            const scoreMatch = line.match(/Score:\s+([\d\.]+)/);
            if (scoreMatch) currentHit.score = parseFloat(scoreMatch[1]);
        }
        else if (currentHit && line.startsWith('  ─')) {
            // Separator - ignore
        }
        else if (currentHit && line.trim() !== '') {
            // Snippet text (anything else that is indented and not matching above)
            if (!line.includes('... and') && !line.includes('Use --limit')) {
                currentHit.snippet += line.trim() + ' ';
            }
        }

        i++;
    }

    if (currentHit) result.hits.push(currentHit);

    return result;
}

app.listen(PORT, () => {
    console.log(`OtzariaSearch Web UI running at http://localhost:${PORT}`);
    console.log(`API Endpoint: http://localhost:${PORT}/api/search?q=query`);
});
