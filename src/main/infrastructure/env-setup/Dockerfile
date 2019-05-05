# From Debian.
FROM debian:8.11-slim

# Sets locale and UTF-8 charset.
ENV TZ=America/Sao_Paulo
ENV LANG_FILE=pt_BR.UTF-8
ENV LANG=pt_BR.utf8
ENV LANGUAGE=pt_BR:pt
RUN apt-get update -y && \
	apt-get purge -y locales && \
	apt-get install -y locales && \
	rm /usr/share/locale/locale.alias && \
	ln -s /etc/locale.alias /usr/share/locale/locale.alias && \
	localedef -i pt_BR -c -f UTF-8 -A /usr/share/locale/locale.alias ${LANG_FILE} && \
	cp /usr/share/zoneinfo/${TZ} /etc/localtime && \
	apt-get purge -y locales && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*

# Installs Docker and other tools.
RUN apt-get update -y && \
	apt-get remove -y docker docker.io && \
	apt-get install -y apt-transport-https ca-certificates \
		gnupg2 curl software-properties-common && \
	curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
	add-apt-repository -y \
		"deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable" && \
	apt-get update -y && \
	apt-get install -y docker-ce && \
	systemctl enable docker && \
	apt-get install -y jq && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/*
	
# Copies the scripts.
RUN mkdir -p /opt/script
COPY script /opt/script
RUN ln -s /opt/script/*.sh /usr/bin && \
	for f in /usr/bin/setup*.sh; \
	do \
		mv -- "$f" "${f%.sh}"; \
	done
	
# Sets the work directory.
RUN mkdir -p /project
WORKDIR /project
VOLUME /project
	
# Entrypoint.
ENTRYPOINT [ "sh", "-c" ] 
