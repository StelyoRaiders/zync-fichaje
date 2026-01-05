/**
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                         ZYNC TABLET - SCRIPT                                   ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 */

// ═══════════════════════════════════════════════════════════════════════════════
// ESTADO
// ═══════════════════════════════════════════════════════════════════════════════

const tabletState = {
    businessId: null,
    businessName: '',
    activeShifts: [],
    recentShifts: [],
    allUsers: [],
    categories: [],
    currentCategory: 'all',
    messages: {},
    pendingForceOut: null
};

// ═══════════════════════════════════════════════════════════════════════════════
// ELEMENTOS DOM
// ═══════════════════════════════════════════════════════════════════════════════

const tabletElements = {
    tablet: document.getElementById('tablet'),
    businessName: document.getElementById('tabletBusinessName'),
    categoryTabs: document.getElementById('categoryTabs'),
    totalHours: document.getElementById('tabletTotalHours'),
    activeCount: document.getElementById('tabletActiveCount'),
    totalUsers: document.getElementById('tabletTotalUsers'),
    activeBadge: document.getElementById('tabletActiveBadge'),
    totalUsersBadge: document.getElementById('tabletTotalUsersBadge'),
    activeShiftsList: document.getElementById('tabletActiveShiftsList'),
    recentShiftsList: document.getElementById('tabletRecentShiftsList'),
    usersTableBody: document.getElementById('tabletUsersTableBody'),
    sortSelect: document.getElementById('tabletSortSelect'),
    refreshBtn: document.getElementById('tabletRefreshBtn'),
    closeBtn: document.getElementById('tabletCloseBtn'),
    toast: document.getElementById('tabletToast'),
    toastMessage: document.getElementById('tabletToastMessage'),
    confirmModal: document.getElementById('tabletConfirmModal'),
    modalMessage: document.getElementById('tabletModalMessage'),
    modalUserInfo: document.getElementById('tabletModalUserInfo'),
    modalUserAvatar: document.getElementById('tabletModalUserAvatar'),
    modalUserName: document.getElementById('tabletModalUserName'),
    modalCancel: document.getElementById('tabletModalCancel'),
    modalConfirm: document.getElementById('tabletModalConfirm'),
    loadingOverlay: document.getElementById('tabletLoadingOverlay')
};

// ═══════════════════════════════════════════════════════════════════════════════
// UTILIDADES
// ═══════════════════════════════════════════════════════════════════════════════

function formatTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    
    if (hours > 0) {
        return `${hours}h ${minutes}min`;
    }
    return `${minutes}min`;
}

function formatTimeShort(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = seconds % 60;
    
    return [
        hours.toString().padStart(2, '0'),
        minutes.toString().padStart(2, '0'),
        secs.toString().padStart(2, '0')
    ].join(':');
}

function showToast(message, type = 'info') {
    tabletElements.toast.textContent = message;
    tabletElements.toast.className = 'toast ' + type;
    tabletElements.toast.classList.remove('hidden');
    
    setTimeout(() => {
        tabletElements.toast.classList.add('hidden');
    }, 3000);
}

function showLoading(show = true) {
    if (show) {
        tabletElements.loadingOverlay.classList.remove('hidden');
    } else {
        tabletElements.loadingOverlay.classList.add('hidden');
    }
}

function getDefaultAvatar(index) {
    return `https://cdn.discordapp.com/embed/avatars/${index % 5}.png`;
}

// ═══════════════════════════════════════════════════════════════════════════════
// RENDERIZADO
// ═══════════════════════════════════════════════════════════════════════════════

function renderCategoryTabs() {
    let html = `
        <button class="category-tab ${tabletState.currentCategory === 'all' ? 'active' : ''}" data-category="all">
            <span class="tab-icon">📊</span>
            <span class="tab-name">General</span>
        </button>
    `;
    
    tabletState.categories.forEach(cat => {
        const isActive = tabletState.currentCategory === cat.name ? 'active' : '';
        html += `
            <button class="category-tab ${isActive}" data-category="${cat.name}">
                <span class="tab-icon">${cat.icon || '📁'}</span>
                <span class="tab-name">${cat.name}</span>
            </button>
        `;
    });
    
    tabletElements.categoryTabs.innerHTML = html;
    
    // Event listeners para tabs
    document.querySelectorAll('.category-tab').forEach(tab => {
        tab.addEventListener('click', () => {
            tabletState.currentCategory = tab.dataset.category;
            renderCategoryTabs();
            renderActiveShifts();
            renderRecentShifts();
            renderUsersTable();
            updateStats();
        });
    });
}

function renderActiveShifts() {
    let shifts = tabletState.activeShifts;
    
    // Filtrar por categoría si no es "all"
    if (tabletState.currentCategory !== 'all') {
        shifts = shifts.filter(s => s.category === tabletState.currentCategory);
    }
    
    if (shifts.length === 0) {
        tabletElements.activeShiftsList.innerHTML = `
            <div class="empty-state">
                <span class="empty-icon">😴</span>
                <span>${tabletState.messages.noActiveShifts || 'Nadie está fichando en esta categoría'}</span>
            </div>
        `;
        tabletElements.activeBadge.textContent = '0';
        return;
    }
    
    tabletElements.activeBadge.textContent = shifts.length;
    
    let html = '';
    shifts.forEach(shift => {
        const avatar = shift.avatar || getDefaultAvatar(shift.discordId?.slice(-1) || 0);
        const elapsedSeconds = shift.elapsedSeconds || 0;
        
        // Mostrar nombre del personaje FiveM si existe, sino nombre de Discord
        const displayName = shift.charName || shift.displayName || shift.username;
        const rankBadge = shift.charRank ? `<span class="rank-badge">${shift.charRank}</span>` : '';
        
        html += `
            <div class="user-card" data-discord-id="${shift.discordId}" data-category="${shift.category}">
                <img class="user-avatar" src="${avatar}" alt="" onerror="this.src='${getDefaultAvatar(0)}'">
                <div class="user-info">
                    <span class="user-name">${displayName} ${rankBadge}</span>
                    <div class="user-meta">
                        <span class="user-tag">@${shift.username}</span>
                        <span>en ${shift.category}</span>
                    </div>
                </div>
                <div class="user-time">
                    <span>⏱️</span>
                    <span class="live-timer" data-start="${elapsedSeconds}">${formatTimeShort(elapsedSeconds)}</span>
                </div>
                <div class="user-actions">
                    <button class="btn-force-out" data-discord-id="${shift.discordId}" data-username="${displayName}" data-avatar="${avatar}" data-category="${shift.category}">
                        ⏹️ Forzar salida
                    </button>
                </div>
            </div>
        `;
    });
    
    tabletElements.activeShiftsList.innerHTML = html;
    
    // Event listeners para botones de forzar salida
    document.querySelectorAll('.btn-force-out').forEach(btn => {
        btn.addEventListener('click', () => {
            openConfirmModal(
                btn.dataset.discordId,
                btn.dataset.username,
                btn.dataset.avatar,
                btn.dataset.category
            );
        });
    });
}

function renderRecentShifts() {
    let shifts = tabletState.recentShifts;
    
    if (tabletState.currentCategory !== 'all') {
        shifts = shifts.filter(s => s.category === tabletState.currentCategory);
    }
    
    // Mostrar solo los últimos 5
    shifts = shifts.slice(0, 5);
    
    if (shifts.length === 0) {
        tabletElements.recentShiftsList.innerHTML = `
            <div class="empty-state">
                <span class="empty-icon">📭</span>
                <span>Sin fichajes recientes</span>
            </div>
        `;
        return;
    }
    
    let html = '';
    shifts.forEach(shift => {
        const avatar = shift.avatar || getDefaultAvatar(shift.discordId?.slice(-1) || 0);
        const duration = formatTime(shift.durationSeconds || 0);
        const timeAgo = shift.timeAgo || 'hace un momento';
        
        html += `
            <div class="user-card">
                <img class="user-avatar" src="${avatar}" alt="" onerror="this.src='${getDefaultAvatar(0)}'">
                <div class="user-info">
                    <span class="user-name">${shift.displayName || shift.username}</span>
                    <div class="user-meta">
                        <span class="user-tag">@${shift.username}</span>
                        <span>Total en ${shift.category}</span>
                    </div>
                </div>
                <div class="user-time">
                    <span>⏱️</span>
                    <span>${timeAgo}</span>
                </div>
            </div>
        `;
    });
    
    tabletElements.recentShiftsList.innerHTML = html;
}

function renderUsersTable() {
    let users = [...tabletState.allUsers];
    
    if (tabletState.currentCategory !== 'all') {
        users = users.filter(u => u.category === tabletState.currentCategory);
    }
    
    // Ordenar
    const sortValue = tabletElements.sortSelect.value;
    switch (sortValue) {
        case 'time-desc':
            users.sort((a, b) => (b.totalSeconds || 0) - (a.totalSeconds || 0));
            break;
        case 'time-asc':
            users.sort((a, b) => (a.totalSeconds || 0) - (b.totalSeconds || 0));
            break;
        case 'name-asc':
            users.sort((a, b) => (a.displayName || a.username).localeCompare(b.displayName || b.username));
            break;
        case 'name-desc':
            users.sort((a, b) => (b.displayName || b.username).localeCompare(a.displayName || a.username));
            break;
    }
    
    tabletElements.totalUsersBadge.textContent = `${users.length} usuarios`;
    
    if (users.length === 0) {
        tabletElements.usersTableBody.innerHTML = `
            <tr>
                <td colspan="4" style="text-align: center; padding: 32px; color: var(--text-muted);">
                    Sin usuarios registrados
                </td>
            </tr>
        `;
        return;
    }
    
    let html = '';
    users.forEach((user, index) => {
        const avatar = user.avatar || getDefaultAvatar(index);
        const isActive = user.isActive || false;
        const statusClass = isActive ? 'active' : 'inactive';
        const statusText = isActive ? (tabletState.messages.active || 'Activo') : (tabletState.messages.inactive || 'Inactivo');
        const totalTime = formatTime(user.totalSeconds || 0);
        
        // Mostrar nombre del personaje FiveM si existe
        const displayName = user.charName || user.displayName || user.username;
        const rankBadge = user.charRank ? `<span class="rank-badge">${user.charRank}</span>` : '';
        
        html += `
            <tr>
                <td>
                    <div class="table-user">
                        <img class="table-user-avatar" src="${avatar}" alt="" onerror="this.src='${getDefaultAvatar(index)}'">
                        <div class="table-user-info">
                            <span class="table-user-name">${displayName} ${rankBadge}</span>
                            <span class="table-user-tag">@${user.username}</span>
                        </div>
                    </div>
                </td>
                <td>
                    <span class="status-badge ${statusClass}">
                        <span class="status-dot"></span>
                        ${statusText}
                    </span>
                </td>
                <td>
                    <div class="table-time">
                        <span>⏱️</span>
                        <span>${totalTime}</span>
                    </div>
                </td>
                <td class="col-actions">
                    ${isActive ? `
                        <button class="btn-force-out" data-discord-id="${user.discordId}" data-username="${user.displayName || user.username}" data-avatar="${avatar}" data-category="${user.category}">
                            ⏹️ Forzar
                        </button>
                    ` : ''}
                </td>
            </tr>
        `;
    });
    
    tabletElements.usersTableBody.innerHTML = html;
    
    // Event listeners
    document.querySelectorAll('.users-table .btn-force-out').forEach(btn => {
        btn.addEventListener('click', () => {
            openConfirmModal(
                btn.dataset.discordId,
                btn.dataset.username,
                btn.dataset.avatar,
                btn.dataset.category
            );
        });
    });
}

function updateStats() {
    let shifts = tabletState.activeShifts;
    let users = tabletState.allUsers;
    
    if (tabletState.currentCategory !== 'all') {
        shifts = shifts.filter(s => s.category === tabletState.currentCategory);
        users = users.filter(u => u.category === tabletState.currentCategory);
    }
    
    // Total horas
    let totalSeconds = users.reduce((sum, u) => sum + (u.totalSeconds || 0), 0);
    tabletElements.totalHours.textContent = formatTime(totalSeconds);
    
    // Contadores
    tabletElements.activeCount.textContent = shifts.length;
    tabletElements.totalUsers.textContent = users.length;
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODAL DE CONFIRMACIÓN
// ═══════════════════════════════════════════════════════════════════════════════

function openConfirmModal(discordId, username, avatar, category) {
    tabletState.pendingForceOut = { discordId, username, avatar, category };
    
    tabletElements.modalUserAvatar.src = avatar || getDefaultAvatar(0);
    tabletElements.modalUserName.textContent = username;
    tabletElements.modalMessage.textContent = tabletState.messages.confirmForceOut || '¿Estás seguro de que quieres forzar la salida de este usuario?';
    
    tabletElements.confirmModal.classList.remove('hidden');
}

function closeConfirmModal() {
    tabletState.pendingForceOut = null;
    tabletElements.confirmModal.classList.add('hidden');
}

function confirmForceOut() {
    if (!tabletState.pendingForceOut) return;
    
    showLoading(true);
    
    fetch(`https://${GetParentResourceName()}/forceClockOut`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            discordId: tabletState.pendingForceOut.discordId,
            category: tabletState.pendingForceOut.category
        })
    }).then(resp => resp.json()).then(response => {
        closeConfirmModal();
        showLoading(false);
    }).catch(err => {
        closeConfirmModal();
        showLoading(false);
        showToast('Error al forzar salida', 'error');
    });
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMUNICACIÓN NUI
// ═══════════════════════════════════════════════════════════════════════════════

function postNUI(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    }).then(resp => resp.json());
}

function close() {
    tabletElements.tablet.classList.add('hidden');
    postNUI('closeTablet');
}

function refresh() {
    postNUI('refreshData');
}

// ═══════════════════════════════════════════════════════════════════════════════
// LIVE TIMERS
// ═══════════════════════════════════════════════════════════════════════════════

let timerInterval = null;

function startLiveTimers() {
    if (timerInterval) {
        clearInterval(timerInterval);
    }
    
    timerInterval = setInterval(() => {
        document.querySelectorAll('.live-timer').forEach(el => {
            let seconds = parseInt(el.dataset.start) || 0;
            seconds++;
            el.dataset.start = seconds;
            el.textContent = formatTimeShort(seconds);
        });
    }, 1000);
}

function stopLiveTimers() {
    if (timerInterval) {
        clearInterval(timerInterval);
        timerInterval = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT LISTENERS
// ═══════════════════════════════════════════════════════════════════════════════

tabletElements.closeBtn.addEventListener('click', close);
tabletElements.refreshBtn.addEventListener('click', refresh);
tabletElements.sortSelect.addEventListener('change', renderUsersTable);
tabletElements.modalCancel.addEventListener('click', closeConfirmModal);
tabletElements.modalConfirm.addEventListener('click', confirmForceOut);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!tabletElements.confirmModal.classList.contains('hidden')) {
            closeConfirmModal();
        } else {
            close();
        }
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// MENSAJES NUI
// ═══════════════════════════════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'showTablet':
            tabletState.businessId = data.businessId;
            tabletState.businessName = data.businessName;
            tabletState.activeShifts = data.activeShifts || [];
            tabletState.recentShifts = data.recentShifts || [];
            tabletState.allUsers = data.allUsers || [];
            tabletState.categories = data.categories || [];
            tabletState.messages = data.messages || {};
            tabletState.currentCategory = 'all';
            
            tabletElements.businessName.textContent = tabletState.businessName;
            
            renderCategoryTabs();
            renderActiveShifts();
            renderRecentShifts();
            renderUsersTable();
            updateStats();
            
            tabletElements.tablet.classList.remove('hidden');
            startLiveTimers();
            break;
            
        case 'hideTablet':
            stopLiveTimers();
            tabletElements.tablet.classList.add('hidden');
            break;
            
        case 'refreshTablet':
            tabletState.activeShifts = data.activeShifts || [];
            tabletState.recentShifts = data.recentShifts || [];
            tabletState.allUsers = data.allUsers || [];
            tabletState.stats = data.stats || {};
            
            renderActiveShifts();
            renderRecentShifts();
            renderUsersTable();
            updateStats();
            break;
            
        case 'forceOutResult':
            showLoading(false);
            if (data.success) {
                showToast(tabletState.messages.forceOutSuccess || 'Salida forzada correctamente', 'success');
            } else {
                showToast(data.message || tabletState.messages.forceOutError || 'Error al forzar salida', 'error');
            }
            break;
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// INICIALIZACIÓN
// ═══════════════════════════════════════════════════════════════════════════════

tabletElements.tablet.classList.add('hidden');
