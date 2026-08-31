# Báo cáo S? c? & Gi?i pháp: Docker x Firewalld (nftables) Outbound Network Drop

**V?n d?:** Các container trong Docker Bridge Network b? m?t hoàn toàn k?t n?i outbound Internet (bao g?m g?i API t?i Cloudflare/WHMCS). Log báo l?i liên t?c connect: no route to host ho?c Host is unreachable. Trong khi dó, các container dùng 
etwork_mode: host ho?t d?ng bình thu?ng.

## Phân tích nguyên nhân c?t lõi (Root Cause)
S? c? này là m?t di?m mù kinh di?n trên các b?n phân ph?i Linux hi?n d?i s? d?ng **Firewalld v?i backend là nftables**:
1. **Xung d?t t?ng Firewall:** Docker daemon ch? t? d?ng tiêm rule NAT và ACCEPT vào b?ng iptables cu. Tuy nhiên, h? di?u hành dánh giá c? b?ng 
ftables (do firewalld qu?n lý). 
2. **Quá trình drop gói tin:** Khi gói tin t? container di qua chu?i FORWARD, l?p iptables cho phép (ACCEPT). Nhung l?p 
ftables (chu?i ilter_FORWARD) th?y gói tin d?n t? m?t interface ?o c?a Docker (không thu?c 	rusted zone) nên l?p t?c dánh ch?n và tr? v? l?i ICMP eject with icmpx admin-prohibited. App bên trong Docker nh?n l?i syscall.EHOSTUNREACH (No route to host).

## Gi?i pháp (Fix)
Ðua toàn b? các interface bridge c?a Docker vào vùng **	rusted** c?a Firewalld.
`ash
# 1. Li?t kê các bridge ?o c?a Docker
ip link show type bridge
# 2. Thêm các bridge vào vùng tin c?y (trusted zone)
firewall-cmd --permanent --zone=trusted --add-interface=docker0
firewall-cmd --permanent --zone=trusted --add-interface=br-xxxxxx
# 3. Reload l?i firewall d? áp d?ng
firewall-cmd --reload
`

## Bài h?c rút ra (Lesson Learned)
1. **Troubleshooting:** G?p l?i 
o route to host t? bên trong Docker, b?t bu?c ki?m tra 
ftables (
ft list ruleset) và Firewalld.
2. **Ki?m tra Packet Drop:** Dùng l?nh 	cpdump -l -n -i <bridge_interface> icmp trên host k?t h?p ping t? container.
3. **C?p nh?t Blueprint:** Các script setup-node.sh ph?i du?c l?p trình d? t? d?ng dò các bridge network c?a Docker và thêm chúng vào trusted zone.
