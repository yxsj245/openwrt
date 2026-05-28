'use strict';
'require view';
'require ui';
'require rpc';
'require poll';

var callServiceList = rpc.declare({
	object: 'rc',
	method: 'list',
	params: ['name']
});

var callServiceAction = rpc.declare({
	object: 'rc',
	method: 'init',
	params: ['name', 'action']
});

var callUbusServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: ['name']
});

var SERVICE_DEFINITIONS = [
	{
		id: 'dockerd',
		name: 'Docker',
		desc: 'Docker容器引擎，用于运行和管理容器化应用',
		management_link: null
	},
	{
		id: 'adguardhome',
		name: 'AdGuard Home',
		desc: 'AdGuard Home DNS广告过滤服务，提供网络级别的广告和跟踪器拦截',
		management_link: '/cgi-bin/luci/admin/services/adguardhome'
	}
];

function getServiceStatus(service) {
	return callServiceList(service.id).then(function(data) {
		var svc = data[service.id];
		if (!svc) {
			return { running: false, enabled: false };
		}
		if (svc.hasOwnProperty('running')) {
			return {
				running: svc.running === true,
				enabled: svc.enabled === true
			};
		}
		return callUbusServiceList(service.id).then(function(svcData) {
			var svcInfo = svcData[service.id];
			var running = false;
			if (svcInfo && svcInfo.instances) {
				for (var k in svcInfo.instances) {
					if (svcInfo.instances[k].running === true) {
						running = true;
						break;
					}
				}
			}
			return {
				running: running,
				enabled: svc.enabled === true
			};
		}).catch(function() {
			return { running: false, enabled: svc.enabled === true };
		});
	}).catch(function() {
		return { running: false, enabled: false };
	});
}

function renderServiceRow(service, container) {
	var row = E('div', {
		'class': 'cbi-section',
		'id': 'service-' + service.id
	});

	var rowInner = E('div', {
		'class': 'cbi-value',
		style: 'display: flex; align-items: center; justify-content: space-between; padding: 15px;'
	});

	var infoDiv = E('div', { style: 'flex: 1;' }, [
		E('div', { style: 'display: flex; align-items: center; gap: 10px;' }, [
			E('strong', { style: 'font-size: 16px;' }, service.name),
			E('span', {
				'id': 'status-badge-' + service.id,
				'class': 'label',
				style: 'font-size: 12px; padding: 2px 8px; border-radius: 3px;'
			}, _('Loading...')),
			E('span', {
				'id': 'enabled-badge-' + service.id,
				'class': 'label',
				style: 'font-size: 12px; padding: 2px 8px; border-radius: 3px; margin-left: 5px;'
			}, _('Checking...'))
		]),
		E('div', { style: 'color: #666; font-size: 13px; margin-top: 5px;' }, service.desc)
	]);

	var btnGroup = E('div', { style: 'display: flex; gap: 8px; align-items: center; flex-shrink: 0;' }, [
		E('button', {
			'class': 'btn cbi-button-action important',
			'id': 'btn-start-' + service.id,
			'click': function() { return handleServiceAction(service, 'start'); },
			style: 'display: none;'
		}, _('Start')),
		E('button', {
			'class': 'btn cbi-button-action negative',
			'id': 'btn-stop-' + service.id,
			'click': function() { return handleServiceAction(service, 'stop'); },
			style: 'display: none;'
		}, _('Stop')),
		E('button', {
			'class': 'btn cbi-button-action',
			'id': 'btn-restart-' + service.id,
			'click': function() { return handleServiceAction(service, 'restart'); },
			style: 'display: none;'
		}, _('Restart')),
		E('button', {
			'class': 'btn cbi-button-positive',
			'id': 'btn-enable-' + service.id,
			'click': function() { return handleServiceAction(service, 'enable'); },
			style: 'display: none;'
		}, _('Enable')),
		E('button', {
			'class': 'btn cbi-button-reset',
			'id': 'btn-disable-' + service.id,
			'click': function() { return handleServiceAction(service, 'disable'); },
			style: 'display: none;'
		}, _('Disable'))
	]);

	rowInner.appendChild(infoDiv);
	rowInner.appendChild(btnGroup);
	row.appendChild(rowInner);
	container.appendChild(row);

	refreshServiceStatus(service);
}

function handleServiceAction(service, action) {
	var actionNames = {
		'enable': _('Enabling'),
		'disable': _('Disabling'),
		'start': _('Starting'),
		'stop': _('Stopping'),
		'restart': _('Restarting')
	};

	var btnId = 'btn-' + action + '-' + service.id;
	var btn = document.getElementById(btnId);
	if (btn) {
		btn.disabled = true;
		btn.textContent = actionNames[action] + '...';
	}

	return callServiceAction(service.id, action).then(function() {
		var delay = (action === 'start' || action === 'restart') ? 3000 : 800;
		setTimeout(function() {
			refreshServiceStatus(service);
		}, delay);
	}).catch(function(e) {
		L.ui.addTimeLimitedNotification(null,
			E('p', _('Service operation failed: %s').format(e.message || e)),
			5000, 'error');
		refreshServiceStatus(service);
	});
}

function refreshServiceStatus(service) {
	getServiceStatus(service).then(function(status) {
		updateServiceUI(service, status);
	});
}

function updateServiceUI(service, status) {
	var statusBadge = document.getElementById('status-badge-' + service.id);
	var enabledBadge = document.getElementById('enabled-badge-' + service.id);
	var btnStart = document.getElementById('btn-start-' + service.id);
	var btnStop = document.getElementById('btn-stop-' + service.id);
	var btnRestart = document.getElementById('btn-restart-' + service.id);
	var btnEnable = document.getElementById('btn-enable-' + service.id);
	var btnDisable = document.getElementById('btn-disable-' + service.id);

	if (statusBadge) {
		if (status.running) {
			statusBadge.textContent = _('Running');
			statusBadge.style.background = '#27ae60';
			statusBadge.style.color = '#fff';
		} else {
			statusBadge.textContent = _('Stopped');
			statusBadge.style.background = '#e74c3c';
			statusBadge.style.color = '#fff';
		}
	}

	if (enabledBadge) {
		if (status.enabled) {
			enabledBadge.textContent = _('Auto-start');
			enabledBadge.style.background = '#2980b9';
			enabledBadge.style.color = '#fff';
		} else {
			enabledBadge.textContent = _('Manual');
			enabledBadge.style.background = '#95a5a6';
			enabledBadge.style.color = '#fff';
		}
	}

	if (btnStart) btnStart.style.display = status.running ? 'none' : '';
	if (btnStop) btnStop.style.display = status.running ? '' : 'none';
	if (btnRestart) btnRestart.style.display = status.running ? '' : 'none';
	if (btnEnable) btnEnable.style.display = status.enabled ? 'none' : '';
	if (btnDisable) btnDisable.style.display = status.enabled ? '' : 'none';

	if (btnStart) { btnStart.disabled = false; btnStart.textContent = _('Start'); }
	if (btnStop) { btnStop.disabled = false; btnStop.textContent = _('Stop'); }
	if (btnRestart) { btnRestart.disabled = false; btnRestart.textContent = _('Restart'); }
	if (btnEnable) { btnEnable.disabled = false; btnEnable.textContent = _('Enable'); }
	if (btnDisable) { btnDisable.disabled = false; btnDisable.textContent = _('Disable'); }
}

return view.extend({
	render: function() {
		var mainContainer = E('div', { 'class': 'cbi-map' });

		mainContainer.appendChild(E('h2', { 'class': 'section-title' }, _('服务管理')));
		mainContainer.appendChild(E('div', { 'class': 'cbi-map-descr' }, [
			_('在此页面可以管理系统中的各项服务。您可以启动、停止服务，以及设置服务是否开机自启。'),
			E('br'),
			E('em', { style: 'color: #e67e22;' }, _('注意：默认情况下所有服务均为关闭状态，需要手动启用。'))
		]));

		var servicesContainer = E('div', {
			'id': 'services-container',
			'class': 'cbi-map',
			style: 'margin-top: 20px;'
		});

		mainContainer.appendChild(servicesContainer);

		SERVICE_DEFINITIONS.forEach(function(service) {
			renderServiceRow(service, servicesContainer);
		});

		var footerNote = E('div', {
			style: 'margin-top: 25px; padding: 12px; background: #f8f9fa; border-radius: 4px; border-left: 4px solid #3498db; font-size: 13px; color: #666;'
		}, [
			E('strong', {}, _('提示：')),
			' ',
			_('启用"开机自启"后，服务会在系统启动时自动运行。启用 Docker 后，您可以通过 Docker 管理页面进行容器、镜像等详细管理。')
		]);

		mainContainer.appendChild(footerNote);

		poll.add(function() {
			SERVICE_DEFINITIONS.forEach(function(service) {
				refreshServiceStatus(service);
			});
		}, 5);

		return mainContainer;
	}
});
