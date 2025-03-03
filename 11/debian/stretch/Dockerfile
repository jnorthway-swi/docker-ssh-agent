# The MIT License
#
#  Copyright (c) 2015, CloudBees, Inc.
#
#  Permission is hereby granted, free of charge, to any person obtaining a copy
#  of this software and associated documentation files (the "Software"), to deal
#  in the Software without restriction, including without limitation the rights
#  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#  copies of the Software, and to permit persons to whom the Software is
#  furnished to do so, subject to the following conditions:
#
#  The above copyright notice and this permission notice shall be included in
#  all copies or substantial portions of the Software.
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#  THE SOFTWARE.

FROM openjdk:11-jdk-stretch
LABEL MAINTAINER="Nicolas De Loof <nicolas.deloof@gmail.com>"

ARG user=jenkins
ARG group=jenkins
ARG uid=1000
ARG gid=1000
ARG JENKINS_AGENT_HOME=/home/${user}

ENV JENKINS_AGENT_HOME ${JENKINS_AGENT_HOME}

RUN groupadd -g ${gid} ${group} \
    && useradd -d "${JENKINS_AGENT_HOME}" -u "${uid}" -g "${gid}" -m -s /bin/bash "${user}"

# Setup SSH server
RUN apt-get update \
    && apt-get install --no-install-recommends -y openssh-server \
    && rm -rf /var/lib/apt/lists/*
RUN sed -i /etc/ssh/sshd_config \
        -e 's/#PermitRootLogin.*/PermitRootLogin no/' \
        -e 's/#RSAAuthentication.*/RSAAuthentication yes/'  \
        -e 's/#PasswordAuthentication.*/PasswordAuthentication no/' \
        -e 's/#SyslogFacility.*/SyslogFacility AUTH/' \
        -e 's/#LogLevel.*/LogLevel INFO/' && \
    mkdir /var/run/sshd

COPY setup-sshd /usr/local/bin/setup-sshd

# Add java to default PATH
RUN ln -sf $(which java) /usr/bin/java

EXPOSE 22

# Install few tools, including git from backports
RUN ( \
      echo "deb http://ftp.debian.org/debian stretch-backports main" >> /etc/apt/sources.list && \
      apt-get update && \
      apt-get -y install -t stretch-backports git git-lfs && \
      apt-get -y install net-tools python bzip2 lbzip2 unzip netcat-openbsd rsync wget \
                         apt-transport-https ca-certificates curl gnupg2 software-properties-common \
                         iproute2 iputils-ping && \
      curl -fsSSL https://download.docker.com/linux/debian/gpg | apt-key add - && \
      add-apt-repository "deb [arch=$(dpkg --print-architecture)] https://download.docker.com/linux/debian $(lsb_release -cs) stable" && \
      apt-get update && \
      apt-get -y install docker-ce && \
      rm -rf /var/lib/apt/lists/* && \
      groupadd -g 233 docker2 && \
      groupadd -g 998 docker3 && \
      groupadd -g 122 docker4 && \
      usermod -a -G docker,docker2,docker3,docker4 "${user}" \
      )

# bash as default shell
RUN ( \
        echo "dash dash/sh boolean false" | debconf-set-selections && \
        mkdir -p /usr/share/man/man1/ && \
        dpkg-reconfigure -p critical dash \
    )

# Add Tini
ENV TINI_VERSION v0.18.0
RUN mkdir -p /opt/tini
RUN ( \
    wget https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini-static-$(dpkg --print-architecture) \
    -O /opt/tini/tini \
)
RUN chmod +x /opt/tini/tini

# custom jq with support for --rawfile
RUN curl -fsSL https://github.com/swi-infra/jq/releases/download/v0.2.8/jq-$(dpkg --print-architecture) -o /usr/bin/jq && \
    chmod +x /usr/bin/jq
VOLUME /opt/tini
ENTRYPOINT ["/opt/tini/tini", "--", "/usr/local/bin/setup-sshd"]

# Add encaps
RUN ( \
        cd /usr/bin && \
        wget https://github.com/swi-infra/jenkins-docker-encaps/archive/master.zip && \
        unzip master.zip && \
        mv jenkins-docker-encaps-master/encaps* . && \
        rm -rf master.zip jenkins-docker-encaps-master \
    )

# Add Agent
ARG VERSION=4.5
RUN ( \
        curl --create-dirs -fsSLo /usr/share/jenkins/slave.jar https://repo.jenkins-ci.org/public/org/jenkins-ci/main/remoting/${VERSION}/remoting-${VERSION}.jar \
        && chmod 755 /usr/share/jenkins \
        && chmod 644 /usr/share/jenkins/slave.jar \
        && ln -sf /usr/share/jenkins/slave.jar /home/jenkins/remoting.jar \
    )

VOLUME "${JENKINS_AGENT_HOME}" "/tmp" "/run" "/var/run"
WORKDIR "${JENKINS_AGENT_HOME}"
