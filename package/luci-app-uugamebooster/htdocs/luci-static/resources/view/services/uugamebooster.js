'use strict';
'require view';
'require ui';
'require rpc';
'require poll';
'require uci';
'require form';

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

function getServiceStatus() {
	return callServiceList('uuplugin').then(function(data) {
		var svc = data['uuplugin'];
		if (!svc) {
			return { running: false, enabled: false };
		}
		return {
			running: svc.running === true,
			enabled: svc.enabled === true
		};
	}).catch(function() {
		return { running: false, enabled: false };
	});
}

function getVersion() {
	return uci.load('uuplugin').then(function() {
		var version = uci.get('uuplugin', 'status', 'version');
		return version || _('Unknown');
	}).catch(function() {
		return _('Unknown');
	});
}

function handleAction(action, btn) {
	if (btn) {
		btn.disabled = true;
		btn.textContent = '...';
	}
	return callServiceAction('uuplugin', action).then(function() {
		setTimeout(function() { refreshUI(); }, 3000);
	}).catch(function(e) {
		L.ui.addTimeLimitedNotification(null,
			E('p', _('Operation failed: %s').format(e.message || e)),
			5000, 'error');
		refreshUI();
	});
}

function refreshUI() {
	getServiceStatus().then(function(status) {
		var statusBadge = document.getElementById('uu-status-badge');
		var enabledBadge = document.getElementById('uu-enabled-badge');
		var btnStart = document.getElementById('uu-btn-start');
		var btnStop = document.getElementById('uu-btn-stop');
		var btnRestart = document.getElementById('uu-btn-restart');
		var btnEnable = document.getElementById('uu-btn-enable');
		var btnDisable = document.getElementById('uu-btn-disable');

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

		if (btnStart) { btnStart.style.display = status.running ? 'none' : ''; btnStart.disabled = false; btnStart.textContent = _('Start'); }
		if (btnStop) { btnStop.style.display = status.running ? '' : 'none'; btnStop.disabled = false; btnStop.textContent = _('Stop'); }
		if (btnRestart) { btnRestart.style.display = status.running ? '' : 'none'; btnRestart.disabled = false; btnRestart.textContent = _('Restart'); }
		if (btnEnable) { btnEnable.style.display = status.enabled ? 'none' : ''; btnEnable.disabled = false; btnEnable.textContent = _('Enable'); }
		if (btnDisable) { btnDisable.style.display = status.enabled ? '' : 'none'; btnDisable.disabled = false; btnDisable.textContent = _('Disable'); }
	});

	getVersion().then(function(version) {
		var versionEl = document.getElementById('uu-version');
		if (versionEl) {
			versionEl.textContent = version;
		}
	});
}

return view.extend({
	render: function() {
		var container = E('div', { 'class': 'cbi-map' }, [
			E('div', { 'class': 'cbi-section' }, [
				E('h2', {}, _('网易UU加速器')),
				E('div', { 'class': 'cbi-section-descr' }, _('网易UU加速器路由器插件，为主机游戏（PS5、Xbox、Switch、PC等）提供网络加速服务。'))
			]),

			E('div', { 'class': 'cbi-section', style: 'margin-top: 20px;' }, [
				E('h3', {}, _('服务状态')),
				E('div', { 'class': 'cbi-value', style: 'display: flex; align-items: center; padding: 15px; background: #f8f9fa; border-radius: 6px;' }, [
					E('div', { style: 'flex: 1;' }, [
						E('div', { style: 'display: flex; align-items: center; gap: 10px; margin-bottom: 8px;' }, [
							E('span', {
								'id': 'uu-status-badge',
								'class': 'label',
								style: 'font-size: 13px; padding: 4px 12px; border-radius: 3px; background: #95a5a6; color: #fff;'
							}, _('Checking...')),
							E('span', {
								'id': 'uu-enabled-badge',
								'class': 'label',
								style: 'font-size: 13px; padding: 4px 12px; border-radius: 3px; background: #95a5a6; color: #fff;'
							}, _('Checking...'))
						]),
						E('div', { style: 'color: #666; font-size: 13px;' }, [
							_('插件版本: '),
							E('span', { 'id': 'uu-version', style: 'font-weight: bold;' }, '---')
						])
					]),
					E('div', { style: 'display: flex; gap: 8px;' }, [
						E('button', {
							'id': 'uu-btn-start',
							'class': 'btn cbi-button-action important',
							'click': function() { return handleAction('start', document.getElementById('uu-btn-start')); },
							style: 'display: none;'
						}, _('Start')),
						E('button', {
							'id': 'uu-btn-stop',
							'class': 'btn cbi-button-action negative',
							'click': function() { return handleAction('stop', document.getElementById('uu-btn-stop')); },
							style: 'display: none;'
						}, _('Stop')),
						E('button', {
							'id': 'uu-btn-restart',
							'class': 'btn cbi-button-action',
							'click': function() { return handleAction('restart', document.getElementById('uu-btn-restart')); },
							style: 'display: none;'
						}, _('Restart')),
						E('button', {
							'id': 'uu-btn-enable',
							'class': 'btn cbi-button-positive',
							'click': function() { return handleAction('enable', document.getElementById('uu-btn-enable')); },
							style: 'display: none;'
						}, _('Enable')),
						E('button', {
							'id': 'uu-btn-disable',
							'class': 'btn cbi-button-reset',
							'click': function() { return handleAction('disable', document.getElementById('uu-btn-disable')); },
							style: 'display: none;'
						}, _('Disable'))
					])
				])
			]),

			E('div', { 'class': 'cbi-section', style: 'margin-top: 20px;' }, [
				E('h3', {}, _('使用说明')),
				E('div', { 'class': 'cbi-value', style: 'padding: 15px; background: #f0f8ff; border-radius: 6px; border-left: 4px solid #3498db;' }, [
					E('ol', { style: 'margin: 0; padding-left: 20px; line-height: 2;' }, [
						E('li', {}, _('点击"启动"按钮开启UU加速器服务')),
						E('li', {}, _('在手机上下载安装"UU主机加速"App')),
						E('li', {}, _('确保手机与路由器连接在同一个局域网')),
						E('li', {}, _('打开App，选择"安装路由器插件"，App会自动发现本路由器')),
						E('li', {}, _('完成绑定后，即可在App中选择游戏进行加速')),
						E('li', {}, _('加速器会自动创建 tun163 虚拟网卡，通过专用线路优化游戏流量'))
					])
				])
			]),

			E('div', { 'class': 'cbi-section', style: 'margin-top: 20px;' }, [
				E('h3', {}, _('注意事项')),
				E('div', { 'class': 'cbi-value', style: 'padding: 15px; background: #fff8e1; border-radius: 6px; border-left: 4px solid #e67e22;' }, [
					E('ul', { style: 'margin: 0; padding-left: 20px; line-height: 2;' }, [
						E('li', {}, _('首次使用需要注册网易UU账号（App内完成）')),
						E('li', {}, _('UU加速器需要会员才能使用全部功能，新用户通常有免费试用')),
						E('li', {}, _('如果NAT类型测试失败，请检查防火墙规则是否正确添加')),
						E('li', {}, _('若与其他代理软件（如OpenClash）同时使用，可能需要添加绕过规则')),
						E('li', {}, _('UU加速器会使用nftables创建XU_ACC_MAIN_*规则表，请勿手动删除'))
					])
				])
			])
		]);

		refreshUI();

		poll.add(function() {
			refreshUI();
		}, 10);

		return container;
	}
});
