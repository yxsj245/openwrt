'use strict';
'require view';
'require form';
'require uci';
'require network';
'require firewall';

return view.extend({
	load() {
		return Promise.all([
			network.getNetworks(),
			network.getDevices()
		]);
	},

	render(data) {
		const networks = data[0];
		const devices = data[1];

		function getNetDevices(net) {
			if (net.isBridge()) {
				const devs = net.getDevices();
				return devs ? devs : [];
			} else {
				return L.toArray(net.getL3Device());
			}
		}

		function renderIfaceBadge(net) {
			const span = E('span', { 'class': 'ifacebadge' + (net.isUp() ? ' ifacebadge-active' : '') }, net.getName() + ': ');
			const devs = getNetDevices(net);

			for (const d of devs) {
				span.appendChild(E('img', {
					'title': d.getI18n(),
					'src': L.resource('icons/%s%s.svg'.format(d.getType(), d.isUp() ? '' : '_disabled'))
				}));
			}

			if (!devs.length)
				span.appendChild(E('em', '(empty)'));

			return span;
		}

		function lookupNetwork(name) {
			for (const n of networks)
				if (n.getName() == name) return n;
			return null;
		}

		let m, s, o;

		m = new form.Map('firewall', _('全锥型 NAT (Full-cone NAT)'),
			_('全锥型 NAT 也称为 NAT1，可以提供更好的 P2P 连接和游戏体验。启用后请务必重启防火墙使规则生效。'));

		s = m.section(form.TypedSection, 'defaults', _('全局设置'));
		s.anonymous = true;
		s.addremove = false;

		o = s.option(form.Flag, 'fullcone', _('启用全锥型 NAT'),
			_('开启后，下方区域中的 IPv4/IPv6 开关才会生效。默认关闭。'));
		o.default = '0';
		o.rmempty = false;

		s = m.section(form.GridSection, 'zone', _('区域设置'),
			_('点击下方开关即可为对应区域启用全锥型 NAT。开启后将替代原有的 Masquerading 规则。'));
		s.addremove = false;
		s.anonymous = true;
		s.nodescriptions = true;

		o = s.option(form.DummyValue, '_name', _('区域'));
		o.modalonly = false;
		o.textvalue = function(section_id) {
			const name = uci.get('firewall', section_id, 'name') || _('(未命名)');
			const netNames = uci.get('firewall', section_id, 'network');
			const ifaces = [];

			if (netNames) {
				const nets = L.toArray(netNames);
				for (const n of nets) {
					const net = lookupNetwork(n);
					if (net)
						ifaces.push(renderIfaceBadge(net));
				}
			}

			if (!ifaces.length)
				ifaces.push(E('span', { 'class': 'ifacebadge' }, E('em', '(empty)')));

			return E('span', { 'class': 'zonebadge', 'style': firewall.getZoneColorStyle(name) }, [ E('strong', name) ].concat(ifaces));
		};

		o = s.option(form.Flag, 'fullcone4', _('IPv4 全锥型'),
			_('对该区域 IPv4 出站流量启用全锥型 NAT (NAT1)。'));
		o.default = '0';
		o.rmempty = false;
		o.editable = true;

		o = s.option(form.Flag, 'fullcone6', _('IPv6 全锥型'),
			_('对该区域 IPv6 出站流量启用全锥型 NAT。通常 IPv6 不需 NAT，仅限特殊场景。'));
		o.default = '0';
		o.rmempty = false;
		o.editable = true;

		return m.render();
	}
});
