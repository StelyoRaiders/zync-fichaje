/**
 * ╔═══════════════════════════════════════════════════════════════════════════════╗
 * ║                         ZYNC FICHAJE - NUI SCRIPT                              ║
 * ╚═══════════════════════════════════════════════════════════════════════════════╝
 * 
 * Script principal para la interfaz NUI del sistema de fichajes.
 */

// ═══════════════════════════════════════════════════════════════════════════════
// ESTADO
// ═══════════════════════════════════════════════════════════════════════════════

const state = {
    businessId: null,
    businessName: '',
    pointName: '',
    isClockedIn: false,
    isLinked: false,
    discordName: '',
    discordAvatar: '',
    currentTime: 0,
    totalTime: 0,
    messages: {},
    timerInterval: null
};

// ═══════════════════════════════════════════════════════════════════════════════
// ELEMENTOS DOM
// ═══════════════════════════════════════════════════════════════════════════════

const elements = {
    app: document.getElementById('app'),
    closeBtn: document.getElementById('closeBtn'),
    logoImage: document.getElementById('logoImage'),
    logoSvg: document.getElementById('logoSvg'),
    logoText: document.getElementById('logoText'),
    businessName: document.getElementById('businessName'),
    pointName: document.getElementById('pointName'),
    statusIndicator: document.getElementById('statusIndicator'),
    statusValue: document.getElementById('statusValue'),
    timeDisplay: document.getElementById('timeDisplay'),
    timeValue: document.getElementById('timeValue'),
    totalTimeDisplay: document.getElementById('totalTimeDisplay'),
    totalTimeValue: document.getElementById('totalTimeValue'),
    linkSection: document.getElementById('linkSection'),
    userCard: document.getElementById('userCard'),
    userAvatar: document.getElementById('userAvatar'),
    linkIcon: document.getElementById('linkIcon'),
    discordName: document.getElementById('discordName'),
    linkForm: document.getElementById('linkForm'),
    linkCode: document.getElementById('linkCode'),
    linkBtn: document.getElementById('linkBtn'),
    linkError: document.getElementById('linkError'),
    clockInBtn: document.getElementById('clockInBtn'),
    clockOutBtn: document.getElementById('clockOutBtn'),
    loadingOverlay: document.getElementById('loadingOverlay'),
    toast: document.getElementById('toast'),
    toastMessage: document.getElementById('toastMessage')
};

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCIONES DE UTILIDAD
// ═══════════════════════════════════════════════════════════════════════════════

function formatTime(seconds) {
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
    elements.toast.textContent = message;
    elements.toast.className = 'toast ' + type;
    elements.toast.classList.remove('hidden');
    
    setTimeout(() => {
        elements.toast.classList.add('hidden');
    }, 3000);
}

function showLoading(show = true) {
    if (show) {
        elements.loadingOverlay.classList.remove('hidden');
    } else {
        elements.loadingOverlay.classList.add('hidden');
    }
}

function startTimer() {
    if (state.timerInterval) {
        clearInterval(state.timerInterval);
    }
    
    state.timerInterval = setInterval(() => {
        state.currentTime++;
        elements.timeValue.textContent = formatTime(state.currentTime);
    }, 1000);
}

function stopTimer() {
    if (state.timerInterval) {
        clearInterval(state.timerInterval);
        state.timerInterval = null;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTUALIZAR UI
// ═══════════════════════════════════════════════════════════════════════════════

function updateUI() {
    // Business info
    elements.businessName.textContent = state.businessName;
    elements.pointName.textContent = state.pointName;
    
    // Status
    if (state.isClockedIn) {
        elements.statusIndicator.classList.add('active');
        elements.statusValue.textContent = state.messages.working || 'Trabajando';
        elements.clockInBtn.classList.add('hidden');
        elements.clockOutBtn.classList.remove('hidden');
        elements.timeDisplay.style.display = 'flex';
        startTimer();
    } else {
        elements.statusIndicator.classList.remove('active');
        elements.statusValue.textContent = state.messages.notWorking || 'Sin fichar';
        elements.clockInBtn.classList.remove('hidden');
        elements.clockOutBtn.classList.add('hidden');
        stopTimer();
        elements.timeValue.textContent = '00:00:00';
    }
    
    // Mostrar tiempo total en categoría (siempre visible)
    if (elements.totalTimeDisplay) {
        elements.totalTimeDisplay.style.display = 'flex';
    }
    if (elements.totalTimeValue) {
        elements.totalTimeValue.textContent = formatTime(state.totalTime);
    }
    
    // User card - mostrar info de Discord si está disponible
    if (state.isLinked && state.discordName) {
        elements.linkSection.classList.remove('hidden');
        if (elements.userCard) {
            elements.userCard.classList.remove('hidden');
        }
        elements.discordName.textContent = state.discordName;
        elements.linkIcon.textContent = '✓';
        
        // Mostrar avatar si está disponible
        if (state.discordAvatar && elements.userAvatar) {
            elements.userAvatar.src = state.discordAvatar;
            elements.userAvatar.classList.remove('hidden');
        } else if (elements.userAvatar) {
            // Avatar por defecto de Discord
            elements.userAvatar.src = 'https://cdn.discordapp.com/embed/avatars/0.png';
            elements.userAvatar.classList.remove('hidden');
        }
        
        elements.linkForm.classList.add('hidden');
    } else {
        // Ocultar sección de vinculación - ya no es necesaria
        elements.linkSection.classList.add('hidden');
        if (elements.userCard) {
            elements.userCard.classList.add('hidden');
        }
        elements.linkForm.classList.add('hidden');
    }
    
    // Siempre permitir fichar (la vinculación es automática con Discord ID)
    elements.clockInBtn.disabled = false;
    elements.clockOutBtn.disabled = false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// COMUNICACIÓN NUI
// ═══════════════════════════════════════════════════════════════════════════════

function postNUI(action, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify(data)
    }).then(resp => resp.json());
}

function close() {
    stopTimer();
    elements.app.classList.add('hidden');
    postNUI('close');
}

// ═══════════════════════════════════════════════════════════════════════════════
// EVENT LISTENERS
// ═══════════════════════════════════════════════════════════════════════════════

// Cerrar
elements.closeBtn.addEventListener('click', close);

// Clock In
elements.clockInBtn.addEventListener('click', () => {
    showLoading(true);
    postNUI('clockIn').then(response => {
        if (response.ok) {
            state.isClockedIn = true;
            state.currentTime = 0;
            updateUI();
            // Toast eliminado - ya se muestra notificación del framework
        }
    }).finally(() => {
        showLoading(false);
    });
});

// Clock Out
elements.clockOutBtn.addEventListener('click', () => {
    showLoading(true);
    postNUI('clockOut').then(response => {
        if (response.ok) {
            state.isClockedIn = false;
            updateUI();
            // Toast eliminado - ya se muestra notificación del framework
        }
    }).finally(() => {
        showLoading(false);
    });
});

// Link Account
elements.linkBtn.addEventListener('click', () => {
    const code = elements.linkCode.value.trim().toUpperCase();
    
    if (code.length < 6) {
        elements.linkError.textContent = 'Código inválido';
        elements.linkError.classList.remove('hidden');
        return;
    }
    
    elements.linkError.classList.add('hidden');
    showLoading(true);
    
    postNUI('linkAccount', { code: code }).then(response => {
        if (response.ok) {
            // Wait for server response via event
        }
    }).finally(() => {
        showLoading(false);
    });
});

// Enter key on link input
elements.linkCode.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        elements.linkBtn.click();
    }
});

// ESC key to close
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        close();
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// MENSAJES NUI DESDE LUA
// ═══════════════════════════════════════════════════════════════════════════════

window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.type) {
        case 'show':
            state.businessId = data.businessId;
            state.businessName = data.businessName;
            state.pointName = data.pointName;
            state.isClockedIn = data.isClockedIn;
            state.isLinked = data.isLinked;
            state.discordName = data.discordName || '';
            state.discordAvatar = data.discordAvatar || '';
            state.currentTime = data.currentTime || 0;
            state.totalTime = data.totalTime || 0;
            state.messages = data.messages || {};
            
            elements.linkCode.value = '';
            elements.linkError.classList.add('hidden');
            
            // Configurar logo personalizado
            console.log('[Zync] Logo URL recibida:', data.logoUrl);
            if (data.logoUrl && data.logoUrl !== '') {
                elements.logoImage.src = data.logoUrl;
                elements.logoImage.classList.remove('hidden');
                elements.logoSvg.classList.add('hidden');
                console.log('[Zync] Logo configurado:', data.logoUrl);
            } else {
                elements.logoImage.classList.add('hidden');
                elements.logoSvg.classList.remove('hidden');
                console.log('[Zync] Usando logo SVG por defecto');
            }
            
            // Configurar texto del logo
            if (data.logoText) {
                elements.logoText.textContent = data.logoText;
            }
            
            // Mostrar tiempo total en categoría
            if (elements.totalTimeValue) {
                elements.totalTimeValue.textContent = formatTime(state.totalTime);
            }
            
            updateUI();
            elements.app.classList.remove('hidden');
            break;
            
        case 'hide':
            stopTimer();
            elements.app.classList.add('hidden');
            break;
            
        case 'updateTime':
            state.currentTime = data.time;
            elements.timeValue.textContent = formatTime(data.time);
            break;
            
        case 'linkResult':
            if (data.success) {
                state.isLinked = true;
                state.discordName = data.discordName || '';
                updateUI();
                showToast('¡Cuenta vinculada correctamente!', 'success');
            } else {
                elements.linkError.textContent = data.message || 'Error al vincular';
                elements.linkError.classList.remove('hidden');
                showToast(data.message || 'Error al vincular', 'error');
            }
            break;
            
        case 'clockResult':
            if (data.success) {
                state.isClockedIn = data.action === 'in';
                if (data.action === 'in') {
                    state.currentTime = 0;
                }
                updateUI();
                // Toast eliminado - ya se muestra notificación del framework
            } else {
                showToast(data.message || 'Error al registrar fichaje', 'error');
            }
            break;
    }
});

// ═══════════════════════════════════════════════════════════════════════════════
// INICIALIZACIÓN
// ═══════════════════════════════════════════════════════════════════════════════

// Hide initially
elements.app.classList.add('hidden');

// Manejadores de error para imágenes
if (elements.logoImage) {
    elements.logoImage.onerror = function() {
        console.log('[Zync] Error cargando logo:', this.src);
        this.classList.add('hidden');
        if (elements.logoSvg) {
            elements.logoSvg.classList.remove('hidden');
        }
    };
    elements.logoImage.onload = function() {
        console.log('[Zync] Logo cargado correctamente:', this.src);
    };
}

if (elements.userAvatar) {
    elements.userAvatar.onerror = function() {
        // Usar avatar por defecto de Discord si falla la carga
        this.src = 'https://cdn.discordapp.com/embed/avatars/0.png';
    };
}

// Development: Show for testing (remove in production)
// elements.app.classList.remove('hidden');
