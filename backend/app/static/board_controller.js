const apiBase = window.location.origin + '/api';

let userId = localStorage.getItem('touchspeak_user_id');
let userName = localStorage.getItem('touchspeak_user_name') || 'Active User';
let currentLanguage = localStorage.getItem('touchspeak_language') || 'en';
let vocabulary = {};

let allCategories = [];
let allCards = [];
let favoriteCardIds = new Set();
let activeTabId = 'favorites';
let searchQuery = '';
let activeDashboardTab = 'categories';

window.addEventListener('DOMContentLoaded', () => {
    initApp();
});

async function initApp() {
    if (!userId) {
        document.getElementById('onboard-panel').style.display = 'flex';
        return;
    }
    document.getElementById('display-name').innerText = userName;
    updateLangUI();
    await loadBoardData();
    refreshData();
}

async function loadBoardData() {
    try {
        const [cats, cards, favs] = await Promise.all([
            fetch(`${apiBase}/communication/categories`).then(r => r.json()),
            fetch(`${apiBase}/communication/cards`).then(r => r.json()),
            fetch(`${apiBase}/communication/favorites/${userId}`).then(r => r.json())
        ]);
        allCategories = cats;
        allCards = cards;
        favoriteCardIds = new Set(favs.map(c => c._id));

        vocabulary = {};
        allCards.forEach(c => {
            vocabulary[c._id] = {
                en: c.translations?.en || c.phrase || c.title,
                ta: c.translations?.ta || c.phrase || c.title,
                hi: c.translations?.hi || c.phrase || c.title
            };
        });

        renderBoardTabs();
        renderBoardGrids();
    } catch (err) {
        console.error("Error loading board data: ", err);
    }
}

function renderBoardTabs() {
    const container = document.getElementById('board-tabs-container');
    if (!container) return;
    container.innerHTML = `<button class="nav-tab ${activeTabId === 'favorites' ? 'active' : ''}" onclick="switchTab('favorites')"><span class="material-icons">star</span> Favorites</button>`;

    allCategories.forEach(cat => {
        const btn = document.createElement('button');
        btn.className = `nav-tab ${activeTabId === cat._id ? 'active' : ''}`;
        btn.innerHTML = `<span class="material-icons">${cat.icon || 'grid_view'}</span> ${cat.name}`;
        btn.onclick = () => switchTab(cat._id);
        container.appendChild(btn);
    });
}

function switchTab(tabId) {
    activeTabId = tabId;
    renderBoardTabs();
    renderBoardGrids();
}

function renderBoardGrids() {
    const container = document.getElementById('board-grids-container');
    if (!container) return;
    container.innerHTML = '';

    const grid = document.createElement('div');
    grid.className = 'grid';

    let displayCards = activeTabId === 'favorites'
        ? allCards.filter(c => favoriteCardIds.has(c._id))
        : allCards.filter(c => c.category_id === activeTabId);

    if (searchQuery.trim()) {
        const q = searchQuery.toLowerCase();
        displayCards = displayCards.filter(c =>
            c.title.toLowerCase().includes(q) ||
            (c.phrase && c.phrase.toLowerCase().includes(q)) ||
            (c.translations?.en && c.translations.en.toLowerCase().includes(q)) ||
            (c.translations?.ta && c.translations.ta.toLowerCase().includes(q)) ||
            (c.translations?.hi && c.translations.hi.toLowerCase().includes(q))
        );
    }

    if (displayCards.length === 0) {
        const msg = document.createElement('div');
        msg.style.cssText = 'grid-column: 1 / -1; padding: 40px; text-align: center; color: var(--text-muted); font-style: italic; font-size: 16px;';
        msg.innerText = searchQuery ? 'No matching cards found.' : (activeTabId === 'favorites' ? 'No favorites yet. Tap stars on other board cards!' : 'No cards in this category.');
        grid.appendChild(msg);
    } else {
        displayCards.sort((a, b) => a.display_order - b.display_order).forEach(card => {
            const cardBtn = document.createElement('button');
            cardBtn.className = 'tile';

            let bgColor = '#4A5568';
            if (card.title.toLowerCase() === 'food') bgColor = 'var(--tile-food)';
            else if (card.title.toLowerCase() === 'water') bgColor = 'var(--tile-water)';
            else if (card.title.toLowerCase() === 'medicine') bgColor = 'var(--tile-medicine)';
            else if (card.title.toLowerCase() === 'restroom') bgColor = 'var(--tile-restroom)';
            else if (card.title.toLowerCase() === 'pain') bgColor = 'var(--tile-pain)';
            else if (card.title.toLowerCase() === 'help') bgColor = 'var(--tile-help)';
            else if (card.title.toLowerCase() === 'happy') bgColor = 'var(--tile-happy)';
            else if (card.title.toLowerCase() === 'sad') bgColor = 'var(--tile-sad)';
            else if (card.title.toLowerCase() === 'angry') bgColor = 'var(--tile-angry)';
            else if (card.title.toLowerCase() === 'scared') bgColor = 'var(--tile-scared)';
            else if (card.title.toLowerCase() === 'tired') bgColor = 'var(--tile-tired)';

            cardBtn.style.backgroundColor = bgColor;
            cardBtn.style.position = 'relative';
            cardBtn.onclick = (e) => {
                if (e.target.closest('.fav-star')) return;
                tapCommunicationCard(card);
            };

            const isFav = favoriteCardIds.has(card._id);
            const favStar = document.createElement('span');
            favStar.className = 'material-icons fav-star';
            favStar.innerText = isFav ? 'star' : 'star_border';
            favStar.style.cssText = `position: absolute; top: 12px; right: 12px; font-size: 24px; color: ${isFav ? 'var(--warning)' : 'rgba(255,255,255,0.6)'}; cursor: pointer;`;
            favStar.onclick = (e) => {
                e.stopPropagation();
                toggleFavoriteCard(card._id);
            };
            cardBtn.appendChild(favStar);

            if (card.image_path) {
                const img = document.createElement('img');
                img.src = card.image_path.startsWith('http') ? card.image_path : window.location.origin + card.image_path;
                img.style.cssText = 'width: 56px; height: 56px; object-fit: cover; border-radius: var(--radius-sm); margin-bottom: 8px;';
                cardBtn.appendChild(img);
            } else {
                const icon = document.createElement('span');
                icon.className = 'material-icons';
                icon.style.fontSize = '56px';
                icon.innerText = card.icon || 'chat_bubble';
                cardBtn.appendChild(icon);
            }

            const lbl = document.createElement('span');
            lbl.className = 'tile-label';
            lbl.innerText = card.title;
            cardBtn.appendChild(lbl);

            grid.appendChild(cardBtn);
        });
    }
    container.appendChild(grid);
}

async function tapCommunicationCard(card) {
    let phrase = card.translations?.[currentLanguage] || card.phrase || card.title;
    speakText(phrase);
    if (userId) {
        try {
            await fetch(`${apiBase}/communication/select`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ user_id: userId, icon_id: card._id, language: currentLanguage })
            });
            setTimeout(refreshData, 100);
        } catch (err) {
            console.error("Log select error:", err);
        }
    }
}

async function toggleFavoriteCard(cardId) {
    if (!userId) return;
    const isFav = favoriteCardIds.has(cardId);
    try {
        const response = await fetch(`${apiBase}/communication/favorites/${userId}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ card_id: cardId, is_favorite: !isFav })
        });
        if (response.ok) {
            if (isFav) favoriteCardIds.delete(cardId);
            else favoriteCardIds.add(cardId);
            renderBoardGrids();
        }
    } catch (err) {
        console.error("Fav toggle error:", err);
    }
}

function handleSearch(q) {
    searchQuery = q;
    renderBoardGrids();
}

function promptCaregiverPasscode() {
    const pin = prompt("Enter Caregiver Passcode (PIN: 1234):");
    if (pin === '1234') {
        openCaregiverDashboard();
    } else if (pin !== null) {
        alert("Access Denied: Incorrect PIN.");
    }
}

function openCaregiverDashboard() {
    document.getElementById('caregiver-overlay').style.display = 'flex';
    switchDashboardTab('categories');
}

function closeCaregiverDashboard() {
    document.getElementById('caregiver-overlay').style.display = 'none';
    loadBoardData();
}

function switchDashboardTab(tabId) {
    activeDashboardTab = tabId;
    document.getElementById('dashboard-categories-tab').classList.toggle('active', tabId === 'categories');
    document.getElementById('dashboard-cards-tab').classList.toggle('active', tabId === 'cards');
    document.getElementById('dashboard-categories').style.display = tabId === 'categories' ? 'block' : 'none';
    document.getElementById('dashboard-cards').style.display = tabId === 'cards' ? 'block' : 'none';
    if (tabId === 'categories') renderDashboardCategories();
    else {
        populateCategoryDropdowns();
        renderDashboardCards();
    }
}

function renderDashboardCategories() {
    const tbody = document.getElementById('categories-table-body');
    if (!tbody) return;
    tbody.innerHTML = '';
    allCategories.forEach(cat => {
        const tr = document.createElement('tr');
        tr.style.borderBottom = '1px solid var(--border)';
        tr.innerHTML = `
            <td style="padding: 10px; font-weight: 600;">${cat.name}</td>
            <td style="padding: 10px;"><span class="material-icons" style="font-size:18px; vertical-align:middle;">${cat.icon}</span> (${cat.icon})</td>
            <td style="padding: 10px;">${cat.display_order}</td>
            <td style="padding: 10px; text-align: right; white-space: nowrap;">
                <button class="dialog-btn" style="padding: 4px 8px; background-color: var(--primary); margin-right: 4px;" onclick="editCategory('${cat._id}', '${cat.name.replace(/'/g, "\\'")}', '${cat.icon}', ${cat.display_order})">Edit</button>
                <button class="dialog-btn" style="padding: 4px 8px; background-color: var(--danger);" onclick="deleteCategory('${cat._id}')">Delete</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function showAddCategoryForm() {
    document.getElementById('cat-form-title').innerText = 'Add New Category';
    document.getElementById('cat-id-input').value = '';
    document.getElementById('cat-name-input').value = '';
    document.getElementById('cat-order-input').value = allCategories.length + 1;
    document.getElementById('cat-icon-input').value = 'grid_view';
    document.getElementById('cat-form-container').style.display = 'block';
}

function editCategory(id, name, icon, order) {
    document.getElementById('cat-form-title').innerText = 'Edit Category';
    document.getElementById('cat-id-input').value = id;
    document.getElementById('cat-name-input').value = name;
    document.getElementById('cat-order-input').value = order;
    document.getElementById('cat-icon-input').value = icon;
    document.getElementById('cat-form-container').style.display = 'block';
}

function hideCategoryForm() {
    document.getElementById('cat-form-container').style.display = 'none';
}

async function saveCategory() {
    const id = document.getElementById('cat-id-input').value;
    const name = document.getElementById('cat-name-input').value.trim();
    const order = parseInt(document.getElementById('cat-order-input').value) || 1;
    const icon = document.getElementById('cat-icon-input').value;
    if (!name) return alert("Name is required");

    const method = id ? 'PUT' : 'POST';
    const url = id ? `${apiBase}/communication/categories/${id}` : `${apiBase}/communication/categories`;
    try {
        const res = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ name, display_order: order, icon })
        });
        if (res.ok) {
            hideCategoryForm();
            await loadBoardData();
            renderDashboardCategories();
        } else {
            const e = await res.json();
            alert("Error: " + e.error);
        }
    } catch (err) { alert("Save error: " + err); }
}

async function deleteCategory(id) {
    if (!confirm("Are you sure? This deletes all associated cards!")) return;
    try {
        const res = await fetch(`${apiBase}/communication/categories/${id}`, { method: 'DELETE' });
        if (res.ok) {
            await loadBoardData();
            renderDashboardCategories();
        }
    } catch (err) { alert("Delete error: " + err); }
}

function populateCategoryDropdowns() {
    const filter = document.getElementById('card-filter-category');
    const input = document.getElementById('card-category-input');
    if (!filter || !input) return;
    const prevFilter = filter.value;
    filter.innerHTML = '<option value="">All Categories</option>';
    input.innerHTML = '';
    allCategories.forEach(cat => {
        filter.innerHTML += `<option value="${cat._id}">${cat.name}</option>`;
        input.innerHTML += `<option value="${cat._id}">${cat.name}</option>`;
    });
    if (prevFilter) filter.value = prevFilter;
}

function renderDashboardCards() {
    const tbody = document.getElementById('cards-table-body');
    if (!tbody) return;
    tbody.innerHTML = '';
    const filterCatId = document.getElementById('card-filter-category').value;
    let displayCards = filterCatId ? allCards.filter(c => c.category_id === filterCatId) : [...allCards];

    displayCards.sort((a, b) => a.display_order - b.display_order).forEach(card => {
        const tr = document.createElement('tr');
        tr.style.borderBottom = '1px solid var(--border)';
        let iconHtml = card.image_path
            ? `<img src="${card.image_path.startsWith('http') ? card.image_path : window.location.origin + card.image_path}" style="width:24px; height:24px; object-fit:cover; border-radius:4px; vertical-align:middle;">`
            : `<span class="material-icons" style="font-size:20px; vertical-align:middle;">${card.icon || 'chat_bubble'}</span>`;
        tr.innerHTML = `
            <td style="padding: 10px; font-weight: 600;">${iconHtml} ${card.title}</td>
            <td style="padding: 10px;">${card.phrase || card.phrase_template || ''}</td>
            <td style="padding: 10px;">${card.display_order}</td>
            <td style="padding: 10px; text-align: right; white-space: nowrap;">
                <button class="dialog-btn" style="padding: 4px 8px; background-color: var(--light); color: var(--text-dark); border: 1px solid var(--border); margin-right: 4px;" onclick="moveCardOrder('${card._id}', 'up')"><span class="material-icons" style="font-size:14px; vertical-align:middle;">arrow_upward</span></button>
                <button class="dialog-btn" style="padding: 4px 8px; background-color: var(--light); color: var(--text-dark); border: 1px solid var(--border); margin-right: 8px;" onclick="moveCardOrder('${card._id}', 'down')"><span class="material-icons" style="font-size:14px; vertical-align:middle;">arrow_downward</span></button>
                <button class="dialog-btn" style="padding: 4px 8px; background-color: var(--primary); margin-right: 4px;" onclick="editCard('${card._id}')">Edit</button>
                <button class="dialog-btn" style="padding: 4px 8px; background-color: var(--danger);" onclick="deleteCard('${card._id}')">Delete</button>
            </td>
        `;
        tbody.appendChild(tr);
    });
}

function showAddCardForm() {
    document.getElementById('card-form-title').innerText = 'Add New Card';
    document.getElementById('card-id-input').value = '';
    document.getElementById('card-title-input').value = '';
    document.getElementById('card-phrase-input').value = '';
    document.getElementById('card-order-input').value = allCards.length + 1;
    document.getElementById('card-image-path-input').value = '';
    document.getElementById('card-image-file').value = '';
    document.getElementById('image-upload-status').innerText = 'No image selected';
    document.getElementById('card-trans-en').value = '';
    document.getElementById('card-trans-ta').value = '';
    document.getElementById('card-trans-hi').value = '';
    document.getElementById('card-icon-input').value = 'restaurant';

    const activeFilter = document.getElementById('card-filter-category').value;
    if (activeFilter) document.getElementById('card-category-input').value = activeFilter;
    document.getElementById('card-form-container').style.display = 'block';
}

function editCard(id) {
    const card = allCards.find(c => c._id === id);
    if (!card) return;
    document.getElementById('card-form-title').innerText = 'Edit Card';
    document.getElementById('card-id-input').value = id;
    document.getElementById('card-title-input').value = card.title;
    document.getElementById('card-phrase-input').value = card.phrase || card.phrase_template || '';
    document.getElementById('card-category-input').value = card.category_id;
    document.getElementById('card-order-input').value = card.display_order;
    document.getElementById('card-image-path-input').value = card.image_path || '';
    document.getElementById('card-image-file').value = '';
    document.getElementById('image-upload-status').innerText = card.image_path ? 'Custom image uploaded.' : 'No custom image';

    document.getElementById('card-trans-en').value = card.translations?.en || '';
    document.getElementById('card-trans-ta').value = card.translations?.ta || '';
    document.getElementById('card-trans-hi').value = card.translations?.hi || '';
    document.getElementById('card-icon-input').value = card.icon || 'restaurant';
    document.getElementById('card-form-container').style.display = 'block';
}

function hideCardForm() {
    document.getElementById('card-form-container').style.display = 'none';
}

async function uploadImageFile(input) {
    const file = input.files[0];
    if (!file) return;
    const fd = new FormData();
    fd.append('image', file);
    document.getElementById('image-upload-status').innerText = 'Uploading...';
    try {
        const res = await fetch(`${apiBase}/communication/upload-image`, { method: 'POST', body: fd });
        if (res.ok) {
            const data = await res.json();
            document.getElementById('card-image-path-input').value = data.url;
            document.getElementById('image-upload-status').innerHTML = `<span style="color:var(--success)">Uploaded!</span>`;
        } else {
            document.getElementById('image-upload-status').innerHTML = `<span style="color:var(--danger)">Failed</span>`;
        }
    } catch (err) {
        document.getElementById('image-upload-status').innerHTML = `<span style="color:var(--danger)">Error</span>`;
    }
}

async function saveCard() {
    const id = document.getElementById('card-id-input').value;
    const title = document.getElementById('card-title-input').value.trim();
    const phrase = document.getElementById('card-phrase-input').value.trim();
    const category_id = document.getElementById('card-category-input').value;
    const order = parseInt(document.getElementById('card-order-input').value) || 1;
    const image_path = document.getElementById('card-image-path-input').value;
    const icon = document.getElementById('card-icon-input').value;

    const en = document.getElementById('card-trans-en').value.trim();
    const ta = document.getElementById('card-trans-ta').value.trim();
    const hi = document.getElementById('card-trans-hi').value.trim();

    if (!title || !phrase || !category_id) return alert("Required fields missing");

    const method = id ? 'PUT' : 'POST';
    const url = id ? `${apiBase}/communication/cards/${id}` : `${apiBase}/communication/cards`;

    const cardData = {
        title, phrase, category_id, display_order: order, image_path, icon,
        translations: { en: en || phrase, ta, hi }
    };

    try {
        const res = await fetch(url, {
            method: method,
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(cardData)
        });
        if (res.ok) {
            hideCardForm();
            await loadBoardData();
            renderDashboardCards();
        } else {
            const e = await res.json();
            alert("Error: " + e.error);
        }
    } catch (err) { alert("Save error: " + err); }
}

async function deleteCard(id) {
    if (!confirm("Are you sure?")) return;
    try {
        const res = await fetch(`${apiBase}/communication/cards/${id}`, { method: 'DELETE' });
        if (res.ok) {
            await loadBoardData();
            renderDashboardCards();
        }
    } catch (err) { alert("Delete error: " + err); }
}

async function moveCardOrder(cardId, direction) {
    const filterCatId = document.getElementById('card-filter-category').value;
    let displayCards = filterCatId ? allCards.filter(c => c.category_id === filterCatId) : [...allCards];
    displayCards.sort((a, b) => a.display_order - b.display_order);

    const idx = displayCards.findIndex(c => c._id === cardId);
    if (idx === -1) return;

    const targetIdx = direction === 'up' ? idx - 1 : idx + 1;
    if (targetIdx < 0 || targetIdx >= displayCards.length) return;

    const temp = displayCards[idx];
    displayCards[idx] = displayCards[targetIdx];
    displayCards[targetIdx] = temp;

    try {
        const res = await fetch(`${apiBase}/communication/cards/reorder`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ card_ids: displayCards.map(c => c._id) })
        });
        if (res.ok) {
            await loadBoardData();
            renderDashboardCards();
        }
    } catch (err) { console.error("Reorder POST error:", err); }
}

function updateLangUI() {
    const btns = document.querySelectorAll('.lang-btn');
    btns.forEach(btn => {
        if (btn.innerText.toLowerCase() === currentLanguage) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });
}

function setLanguage(lang) {
    currentLanguage = lang;
    localStorage.setItem('touchspeak_language', lang);
    updateLangUI();
    loadPredictions();
    if (userId) {
        fetch(`${apiBase}/users/${userId}/preferences`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ preferred_language: lang })
        }).catch(err => console.log("Failed to sync preference: ", err));
    }
    renderBoardGrids();
}

async function submitOnboarding() {
    const input = document.getElementById('username-input');
    const langSelect = document.getElementById('lang-select');
    const nameValue = input.value.trim() || 'Demo Speaker';
    const langValue = langSelect.value;
    try {
        const response = await fetch(`${apiBase}/users`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: nameValue, preferred_language: langValue, age: 12,
                caregiver: { name: "Demo Caregiver", phone: "+919876543210", email: "caregiver@demo.com" }
            })
        });
        if (response.ok) {
            const user = await response.json();
            userId = user._id; userName = user.name; currentLanguage = user.preferred_language;
            localStorage.setItem('touchspeak_user_id', userId);
            localStorage.setItem('touchspeak_user_name', userName);
            localStorage.setItem('touchspeak_language', currentLanguage);
            document.getElementById('onboard-panel').style.display = 'none';
            initApp();
        } else {
            alert("Failed to register profile.");
        }
    } catch (err) {
        alert("Connection refused by Flask server.");
    }
}

async function useSeededDemoUser() {
    try {
        const response = await fetch(`${apiBase}/users`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                name: "Demo User", preferred_language: "en", age: 10,
                caregiver: { name: "Demo Caregiver", phone: "+919876543210", email: "demo@example.com" }
            })
        });
        let profile = response.ok ? await response.json() : { _id: "6a49557193813a68d03ff4dd", name: "Demo User", preferred_language: "en" };
        userId = profile._id; userName = profile.name; currentLanguage = profile.preferred_language;
        localStorage.setItem('touchspeak_user_id', userId);
        localStorage.setItem('touchspeak_user_name', userName);
        localStorage.setItem('touchspeak_language', currentLanguage);
        document.getElementById('onboard-panel').style.display = 'none';
        initApp();
    } catch (err) {
        userId = "6a49557193813a68d03ff4dd"; userName = "Demo User"; currentLanguage = "en";
        localStorage.setItem('touchspeak_user_id', userId);
        localStorage.setItem('touchspeak_user_name', userName);
        localStorage.setItem('touchspeak_language', currentLanguage);
        document.getElementById('onboard-panel').style.display = 'none';
        initApp();
    }
}

function resetProfile() {
    if (confirm("Reset current user profile?")) {
        localStorage.removeItem('touchspeak_user_id');
        localStorage.removeItem('touchspeak_user_name');
        location.reload();
    }
}

function refreshData() {
    loadPredictions();
    loadHistory();
    loadFrequent();
}

async function loadPredictions() {
    if (!userId) return;
    const container = document.getElementById('prediction-chips-container');
    try {
        const response = await fetch(`${apiBase}/predict/${userId}`);
        if (response.ok) {
            const data = await response.json();
            const list = data.predictions;
            if (list && list.length > 0) {
                container.innerHTML = '';
                list.forEach(p => {
                    let phrase = p.phrase_text || p.icon_id;
                    if (vocabulary[p.icon_id]) {
                        phrase = vocabulary[p.icon_id][currentLanguage] || vocabulary[p.icon_id]['en'] || phrase;
                    }
                    const btn = document.createElement('button');
                    btn.className = 'prediction-chip';
                    btn.innerHTML = `<span class="material-icons" style="font-size: 16px">auto_awesome</span> ${phrase}`;
                    btn.onclick = () => {
                        speakText(phrase);
                        if (userId) {
                            fetch(`${apiBase}/communication/select`, {
                                method: 'POST',
                                headers: { 'Content-Type': 'application/json' },
                                body: JSON.stringify({ user_id: userId, icon_id: p.icon_id, language: currentLanguage })
                            }).then(() => setTimeout(refreshData, 100));
                        }
                    };
                    container.appendChild(btn);
                });
            } else {
                container.innerHTML = '<span class="cold-start-indicator">No recommendations available. Select icons to train the model.</span>';
            }
        }
    } catch (err) {
        console.error("Predictions fetch error: ", err);
        container.innerHTML = '<span class="cold-start-indicator">Offline mode: select icons below to log locally.</span>';
    }
}

async function loadHistory() {
    if (!userId) return;
    const listElem = document.getElementById('history-list-elem');
    try {
        const response = await fetch(`${apiBase}/communication/history/${userId}?limit=8`);
        if (response.ok) {
            const list = await response.json();
            listElem.innerHTML = '';
            if (list.length === 0) {
                listElem.innerHTML = '<li style="padding: 10px; color: var(--text-muted); text-align: center;">No logs yet. Tap icons above!</li>';
                return;
            }
            list.forEach(item => {
                const li = document.createElement('li');
                li.className = 'history-item';
                const time = new Date(item.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
                li.innerHTML = `<span class="history-text">${item.phrase_text}</span><span class="history-time">${time} (${item.language.toUpperCase()})</span>`;
                listElem.appendChild(li);
            });
        }
    } catch (err) { console.error("History fetch error: ", err); }
}

async function loadFrequent() {
    if (!userId) return;
    const listElem = document.getElementById('frequent-list-elem');
    try {
        const response = await fetch(`${apiBase}/communication/frequent/${userId}?limit=5`);
        if (response.ok) {
            const list = await response.json();
            listElem.innerHTML = '';
            if (list.length === 0) {
                listElem.innerHTML = '<li style="padding: 10px; color: var(--text-muted); text-align: center;">Tap icons to compile statistics.</li>';
                return;
            }
            list.forEach(item => {
                const li = document.createElement('li');
                li.className = 'frequent-item';
                li.innerHTML = `
                    <div class="frequent-details">
                        <span class="material-icons" style="font-size: 16px; color: var(--primary);">chat_bubble_outline</span>
                        <span class="history-text">${item.phrase_text}</span>
                    </div>
                    <span class="count-badge">${item.use_count}x</span>
                `;
                listElem.appendChild(li);
            });
        }
    } catch (err) { console.log("Frequent logs fetch error: ", err); }
}

function hasTamilSpeechVoice() {
    if (!('speechSynthesis' in window)) return false;
    return window.speechSynthesis.getVoices().some(v =>
        v.lang.toLowerCase() === 'ta-in' || v.lang.toLowerCase().startsWith('ta') || v.name.toLowerCase().includes('tamil')
    );
}

async function speakText(text) {
    console.log(`[TTS] Request to speak text: "${text}" in language: "${currentLanguage}"`);
    if (!currentLanguage) return;

    const useBackendTts = document.getElementById('backend-tts-toggle').checked;
    let forceBackend = false;
    if (currentLanguage === 'ta' && !hasTamilSpeechVoice()) {
        console.log("[TTS] No Tamil voice in browser. Forcing Backend Fallback.");
        forceBackend = true;
    }

    if (useBackendTts || forceBackend) {
        try {
            const response = await fetch(`${apiBase}/tts/speak`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ text: text, language: currentLanguage })
            });
            if (response.ok) {
                const data = await response.json();
                const base64Audio = data.audio_base64;
                const audioBlob = base64ToBlob(base64Audio, 'audio/mp3');
                const audioUrl = URL.createObjectURL(audioBlob);
                const audio = new Audio(audioUrl);
                audio.play().then(() => {
                    console.log("[TTS] Audio played successfully.");
                }).catch(playErr => {
                    console.error("[TTS Error] Failed to play backend audio stream:", playErr);
                });
                if (data.is_mock) {
                    speakBrowserSpeech(text);
                }
            } else {
                speakBrowserSpeech(text);
            }
        } catch (err) {
            speakBrowserSpeech(text);
        }
    } else {
        speakBrowserSpeech(text);
    }
}

function speakBrowserSpeech(text) {
    if ('speechSynthesis' in window) {
        const utterance = new SpeechSynthesisUtterance(text);
        const voicesMap = { 'en': 'en-IN', 'ta': 'ta-IN', 'hi': 'hi-IN' };
        const targetLocale = voicesMap[currentLanguage];
        if (!targetLocale) return;

        utterance.lang = targetLocale;
        utterance.rate = 0.85;

        const voices = window.speechSynthesis.getVoices();
        let selectedVoice = null;
        if (currentLanguage === 'ta') {
            selectedVoice = voices.find(v => v.lang.toLowerCase() === 'ta-in' || v.lang.toLowerCase().startsWith('ta') || v.name.toLowerCase().includes('tamil'));
        } else if (currentLanguage === 'hi') {
            selectedVoice = voices.find(v => v.lang.toLowerCase() === 'hi-in' || v.name.toLowerCase().includes('hindi'));
        } else if (currentLanguage === 'en') {
            selectedVoice = voices.find(v => v.lang.toLowerCase() === 'en-in' || v.name.toLowerCase().includes('english'));
        }

        if (selectedVoice) utterance.voice = selectedVoice;
        window.speechSynthesis.speak(utterance);
    }
}

function base64ToBlob(base64, mimeType) {
    const byteCharacters = atob(base64);
    const byteNumbers = new Array(byteCharacters.length);
    for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
    }
    return new Blob([new Uint8Array(byteNumbers)], { type: mimeType });
}

const sosTranslations = {
    'en': 'Emergency! I need immediate assistance.',
    'ta': 'அவசர உதவி தேவை. தயவுசெய்து எனக்கு உதவுங்கள்.',
    'hi': 'मुझे तुरंत सहायता चाहिए। कृपया मेरी मदद करें।'
};

const sendingTranslations = {
    'en': 'Sending emergency alert.',
    'ta': 'அவசர எச்சரிக்கை அனுப்பப்படுகிறது.',
    'hi': 'आपातकालीन चेतावनी भेजी जा रही है।'
};

let sosTimer = null;

function triggerSOS() {
    if (sosTimer) { clearInterval(sosTimer); sosTimer = null; }
    closeAllSOSOverlays();
    document.getElementById('sos-confirm-overlay').style.display = 'flex';
}

function cancelSOSConfirm() {
    document.getElementById('sos-confirm-overlay').style.display = 'none';
}

function proceedToSOSCountdown() {
    document.getElementById('sos-confirm-overlay').style.display = 'none';
    document.getElementById('sos-countdown-overlay').style.display = 'flex';
    let countdownSeconds = 5;
    document.getElementById('countdown-number').innerText = countdownSeconds;
    sosTimer = setInterval(() => {
        countdownSeconds--;
        if (countdownSeconds <= 0) {
            clearInterval(sosTimer); sosTimer = null;
            document.getElementById('sos-countdown-overlay').style.display = 'none';
            dispatchSOS();
        } else {
            document.getElementById('countdown-number').innerText = countdownSeconds;
        }
    }, 1000);
}

function cancelSOSCountdown() {
    if (sosTimer) { clearInterval(sosTimer); sosTimer = null; }
    document.getElementById('sos-countdown-overlay').style.display = 'none';
}

async function dispatchSOS() {
    document.getElementById('sos-loading-overlay').style.display = 'flex';
    speakText(sendingTranslations[currentLanguage] || sendingTranslations['en']);

    if (!navigator.geolocation) {
        showSOSError("Location coordinates are currently unavailable.");
        return;
    }

    navigator.geolocation.getCurrentPosition(
        async (position) => {
            const lat = position.coords.latitude;
            const lng = position.coords.longitude;
            if (!userId) return showSOSError("No user ID is configured.");
            try {
                const response = await fetch(`${apiBase}/emergency/sos`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ user_id: userId, latitude: lat, longitude: lng, message: "Emergency! I need help immediately." })
                });
                if (response.ok) {
                    const res = await response.json();
                    await speakText(sosTranslations[currentLanguage] || sosTranslations['en']);
                    document.getElementById('sos-loading-overlay').style.display = 'none';
                    showSOSSuccess(res, lat, lng);
                } else {
                    showSOSError("SOS rejected by server.");
                }
            } catch (err) {
                showSOSError("Could not send alert.");
            }
        },
        (error) => {
            showSOSError("Location coordinates are currently unavailable.");
        },
        { enableHighAccuracy: true, timeout: 8000 }
    );
}

function showSOSError(msg) {
    closeAllSOSOverlays();
    document.getElementById('sos-error-overlay').style.display = 'flex';
    document.getElementById('sos-error-msg').innerText = msg;
}

function showSOSSuccess(data, lat, lng) {
    closeAllSOSOverlays();
    const emergencyId = data.log_id || 'N/A';
    const timestamp = data.timestamp || 'N/A';
    const caregiverName = data.caregiver_name || 'N/A';
    const notificationStatus = data.notification_status || 'Failed';
    const emailStatus = data.email_status || 'Not Sent';
    const mapsUrl = data.google_maps_url || `https://www.google.com/maps?q=${lat},${lng}`;

    const contentElem = document.getElementById('sos-success-content');
    contentElem.innerHTML = `
        <div><b>Emergency ID:</b><br><span style="word-break: break-all; opacity: 0.85;">${emergencyId}</span></div>
        <div><b>Date & Time:</b><br><span style="opacity: 0.85;">${timestamp}</span></div>
        <div><b>Caregiver:</b><br><span style="opacity: 0.85;">${caregiverName}</span></div>
        <div style="display: flex; align-items: center; gap: 8px;">
            <b>Notification FCM:</b>
            <span style="color: ${notificationStatus === 'Success' ? 'var(--success)' : '#e0a800'}; font-weight: 700;">${notificationStatus}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 8px;">
            <b>Email Backup:</b>
            <span style="color: ${emailStatus === 'Success' ? 'var(--success)' : 'var(--danger)'}; font-weight: 700;">${emailStatus}</span>
        </div>
    `;
    document.getElementById('sos-map-link').href = mapsUrl;
    document.getElementById('sos-success-overlay').style.display = 'flex';
    refreshData();
}

function closeSOSSuccessDialog() {
    document.getElementById('sos-success-overlay').style.display = 'none';
}

function closeSOSErrorDialog() {
    document.getElementById('sos-error-overlay').style.display = 'none';
}

function closeAllSOSOverlays() {
    document.getElementById('sos-confirm-overlay').style.display = 'none';
    document.getElementById('sos-countdown-overlay').style.display = 'none';
    document.getElementById('sos-loading-overlay').style.display = 'none';
    document.getElementById('sos-success-overlay').style.display = 'none';
    document.getElementById('sos-error-overlay').style.display = 'none';
}
