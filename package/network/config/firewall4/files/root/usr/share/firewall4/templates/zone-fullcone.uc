{# /usr/share/firewall4/templates/zone-fullcone.uc #}
{# zone-fullcone.uc template for fullcone NAT support #}
{% if (direction == "dstnat"): %}
		meta nfproto {{ fw4.nfproto(family) }} fullcone comment "!fw4: Handle {{ zone.name }} {{ fw4.nfproto(family, true) }} fullcone NAT dstnat traffic"
{% else %}
		meta nfproto {{ fw4.nfproto(family) }} fullcone comment "!fw4: Handle {{ zone.name }} {{ fw4.nfproto(family, true) }} fullcone NAT srcnat traffic"
{% endif %}
