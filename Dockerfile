FROM ubuntu/squid:latest
RUN apt update && \
	apt upgrade -y && \
	apt install squid-openssl -y && \
	mkdir -p /var/lib/squid && \
	/usr/lib/squid/security_file_certgen -c -s /var/lib/squid/ssl_db -M 20MB
