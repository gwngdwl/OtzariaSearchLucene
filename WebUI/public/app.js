document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('searchForm');
    const searchInput = document.getElementById('searchInput');
    const categoryInput = document.getElementById('categoryInput');
    const bookInput = document.getElementById('bookInput');
    const limitInput = document.getElementById('limitInput');

    const resultsList = document.getElementById('resultsList');
    const loader = document.getElementById('loader');
    const stats = document.getElementById('stats');

    form.addEventListener('submit', async (e) => {
        e.preventDefault();

        const query = searchInput.value.trim();
        if (!query) return;

        // UI Reset
        resultsList.innerHTML = '';
        stats.classList.add('hidden');
        loader.classList.remove('hidden');

        try {
            // Build URL
            const url = new URL('/api/search', window.location.href);
            url.searchParams.append('q', query);
            url.searchParams.append('limit', limitInput.value);

            if (categoryInput.value.trim()) {
                url.searchParams.append('category', categoryInput.value.trim());
            }
            if (bookInput.value.trim()) {
                url.searchParams.append('book', bookInput.value.trim());
            }

            // Fetch
            const response = await fetch(url);
            const data = await response.json();

            if (!response.ok) {
                throw new Error(data.error || 'אירעה שגיאה בחיפוש');
            }

            renderResults(data);

        } catch (error) {
            console.error('Search error:', error);
            stats.innerHTML = `<span style="color: #ef4444;">שגיאה: ${error.message}</span>`;
            stats.classList.remove('hidden');
        } finally {
            loader.classList.add('hidden');
        }
    });

    function renderResults(data) {
        // Stats
        stats.innerHTML = `מצאנו <b>${data.meta.totalFound.toLocaleString()}</b> תוצאות ב-${data.meta.elapsedMs.toFixed(0)} מיל-שניות`;
        stats.classList.remove('hidden');

        // Results
        if (!data.hits || data.hits.length === 0) {
            resultsList.innerHTML = '<div style="text-align:center; color: var(--text-muted); padding: 3rem; font-size: 1.2rem;">לא נמצאו תוצאות לחיפוש זה.</div>';
            return;
        }

        const fragment = document.createDocumentFragment();

        data.hits.forEach((hit, index) => {
            const card = document.createElement('div');
            card.className = 'result-card';
            card.style.animationDelay = `${index * 0.05}s`;

            // Parse highlight
            // The console output uses console colors, but we removed them or just have raw text.
            // We'll highlight the search query terms manually in CSS if they match, or just show the snippet.
            let snippetHtml = hit.snippet;

            // Basic highlight injection for web (case insensitive replace)
            const queryWords = data.meta.query.replace(/['"]/g, '').split(' ');
            queryWords.forEach(word => {
                if (word.length > 1) {
                    const regex = new RegExp(`(${word})`, 'gi');
                    snippetHtml = snippetHtml.replace(regex, '<mark>$1</mark>');
                }
            });

            card.innerHTML = `
                <div class="result-header">
                    <div>
                        <span class="book-title">${hit.bookTitle}</span>
                        <span class="rank-badge">#${hit.rank}</span>
                    </div>
                    ${hit.reference ? `<div class="reference">${hit.reference}</div>` : ''}
                </div>
                ${hit.category ? `<div class="category">${hit.category}</div>` : ''}
                <div class="snippet">${snippetHtml}</div>
                <div class="score">Score: ${hit.score.toFixed(4)}</div>
            `;

            fragment.appendChild(card);
        });

        resultsList.appendChild(fragment);
    }
});
