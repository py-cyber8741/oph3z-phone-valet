let Lang = {};

function closeApp() { window.parent.postMessage({ type: 'oph3z:close' }, '*'); }
function phoneToast(toastType, title, body) { window.parent.postMessage({ type: 'oph3z:toast', toastType: toastType, title: title, body: body }, '*'); }
function phoneFetch(name, data) {
    var resource = window.location.hostname.replace(/^cfx-nui-/, '') || 'oph3z-valet';
    return fetch('https://' + resource + '/' + name, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then(function (r) { return r.json().catch(function () { return {}; }); });
}

async function loadLocales() {
    Lang = await phoneFetch('getLocales');
    document.getElementById('app-title').innerText = Lang.app_name;
    document.getElementById('app-desc').innerText = Lang.app_desc;
    document.getElementById('close').innerText = Lang.close_app;
}

async function loadVehicles() {
    const listEl = document.getElementById('vehicle-list');
    listEl.innerHTML = `<p>${Lang.loading}</p>`;
    
    const vehicles = await phoneFetch('getValetVehicles'); 
    listEl.innerHTML = '';
    
    if (!vehicles || vehicles.length === 0) {
        listEl.innerHTML = `<p>${Lang.no_vehicles}</p>`;
        return;
    }

    vehicles.forEach(veh => {
        const btn = document.createElement('button');
        btn.className = 'vehicle-btn'; 
        
        let statusText = '';
        let isAvailable = false;
        
        if (veh.state === 1) {
            statusText = `<span style="color: #34c759; font-size: 0.8rem; font-weight: bold;">${Lang.status_available}</span>`;
            isAvailable = true;
        } else if (veh.state === 0) {
            statusText = `<span style="color: #ff9f0a; font-size: 0.8rem; font-weight: bold;">${Lang.status_out}</span>`;
            btn.classList.add('disabled-btn');
            btn.disabled = true;
        } else if (veh.state === 2) {
            statusText = `<span style="color: #ff453a; font-size: 0.8rem; font-weight: bold;">${Lang.status_impounded}</span>`;
            btn.classList.add('disabled-btn');
            btn.disabled = true;
        }

        const vehName = veh.custom_name || veh.vehicle;
        const enginePct = Math.round((veh.engine || 1000) / 10);
        const bodyPct = Math.round((veh.body || 1000) / 10);
        const fuelPct = Math.round(veh.fuel || 100);

        const getProgressClass = (val) => val < 30 ? 'danger' : (val < 60 ? 'warn' : 'good');

        btn.innerHTML = `
            <div class="veh-header">
                <div class="veh-title-group">
                    <span class="veh-name">${vehName}</span>
                    <span class="veh-plate">${veh.plate}</span>
                </div>
                <div class="veh-status">
                    ${statusText}
                </div>
            </div>
            <div class="veh-stats">
                <div class="stat-item">
                    <span>${Lang.engine} ${enginePct}%</span>
                    <progress value="${enginePct}" max="100" class="${getProgressClass(enginePct)}"></progress>
                </div>
                <div class="stat-item">
                    <span>${Lang.body} ${bodyPct}%</span>
                    <progress value="${bodyPct}" max="100" class="${getProgressClass(bodyPct)}"></progress>
                </div>
                <div class="stat-item">
                    <span>${Lang.fuel} ${fuelPct}%</span>
                    <progress value="${fuelPct}" max="100" class="${getProgressClass(fuelPct)}"></progress>
                </div>
            </div>
        `;

        if (isAvailable) {
            btn.addEventListener('click', () => {
                phoneToast('success', Lang.dispatch_complete, `${veh.plate} ${Lang.is_on_the_way}`);
                phoneFetch('callVehicle', { plate: veh.plate, model: veh.vehicle });
                closeApp(); 
            });
        }
        
        listEl.appendChild(btn);
    });
}

// アプリが開かれた時の処理
window.addEventListener('message', async function (e) {
    var msg = e.data || {};
    if (msg.type === 'oph3z:init') {
        await loadLocales();
        loadVehicles();
    }
});

document.getElementById('close').addEventListener('click', closeApp);