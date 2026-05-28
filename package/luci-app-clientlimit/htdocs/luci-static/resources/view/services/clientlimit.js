'use strict';
'require view';
'require form';
'require uci';
'require tools.widgets as widgets';

return view.extend({
	load: function() {
		return uci.load('clientlimit');
	},

	render: function() {
		var m, s, o;

		m = new form.Map('clientlimit', _('客户端带宽限速'),
			_('基于 nftables 的客户端带宽限速管理，支持对局域网内每个 IP 设置独立的上下行限速。'));

		s = m.section(form.NamedSection, 'settings', 'settings');
		s.anonymous = false;
		s.addremove = false;

		o = s.option(form.Flag, 'enabled', _('启用限速'));
		o.rmempty = false;

		o = s.option(widgets.NetworkSelect, 'lan_interfaces', _('内网接口'),
			_('指定哪些接口为内网接口，用于识别并列出在线的内网客户端列表。'));
		o.multiple = true;
		o.nocreate = true;
		o.rmempty = false;
		o.default = 'lan';

		s = m.section(form.GridSection, 'client', _('客户端限速规则'));

		s.sortable = false;
		s.anonymous = false;
		s.addremove = true;
		s.nodescriptions = true;

		s.sectiontitle = _('客户端限速规则');
		s.addbtntitle = _('添加限速规则');

		o = s.option(form.Flag, 'enabled', _('启用'));
		o.rmempty = false;
		o.editable = true;

		o = s.option(form.Value, 'name', _('名称'));
		o.rmempty = true;
		o.placeholder = _('备注名称，如：客厅电视');
		o.datatype = 'string';

		o = s.option(form.Value, 'ip', _('IP 地址'));
		o.rmempty = false;
		o.datatype = 'ip4addr';
		o.placeholder = '192.168.1.100';

		o = s.option(form.Value, 'download', _('下载限速 (KB/s)'));
		o.rmempty = false;
		o.datatype = 'uinteger';
		o.placeholder = '0';
		o.default = '0';

		o = s.option(form.Value, 'upload', _('上传限速 (KB/s)'));
		o.rmempty = false;
		o.datatype = 'uinteger';
		o.placeholder = '0';
		o.default = '0';

		return m.render();
	}
});
