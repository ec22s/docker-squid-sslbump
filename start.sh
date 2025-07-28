## settings
NIC=wlp4s0
PORT_HTTP_SOURCE=80
PORT_HTTP_SQUID=3128
PORT_HTTPS_SOURCE=443
PORT_HTTPS_SQUID=3129

## stop container
docker compose down -v
docker volume ls -qf dangling=true | xargs -r docker volume rm

## routing
COM_COMMON="iptables -t nat -A PREROUTING -i $NIC -p tcp -j REDIRECT"
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -X
sudo $COM_COMMON --dport $PORT_HTTP_SOURCE --to-port $PORT_HTTP_SQUID
sudo $COM_COMMON --dport $PORT_HTTPS_SOURCE --to-port $PORT_HTTPS_SQUID
sudo sh -c 'iptables-save > /etc/iptables/rules.v4'

# start container
sudo systemctl restart docker
docker compose up -d --build

## confirmation
docker ps -a
# netstat -ntl
# sudo iptables -L -t nat
# cat /etc/iptables/rules.v4
# docker exec -it squid tail -f /var/log/squid/access.log
