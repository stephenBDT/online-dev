# Frappe Bench Dockerfile
FROM bitnami/minideb
LABEL author=oo-online

RUN apt update && DEBIAN_FRONTEND="noninteractive" apt install tzdata
RUN apt update && apt install python3-minimal build-essential python3-setuptools python3-pip git software-properties-common virtualenv mariadb-server-10.3 redis-server curl cron sudo vim nodejs -y
RUN pip3 install frappe-bench
RUN curl -sL https://deb.nodesource.com/setup_12.x | bash -
RUN apt-get install -y nodejs
RUN npm install -g yarn

Run adduser frappe
RUN usermod -aG sudo frappe
RUN echo frappe:frappe | chpasswd
RUN mkdir -p /home/frappe/frappe-bench ; chown -R frappe:frappe /home/frappe/frappe-bench

WORKDIR /home/frappe/

COPY ./debian.cnf /etc/mysql/debian.cnf
COPY ./my.cnf /etc/mysql/mariadb.conf.d/my.cnf

RUN mkdir -p /home/frappe/frappe-bench/sites ; chown -R frappe:frappe /home/frappe/frappe-bench/sites
COPY ./common_site_config.json /home/frappe/frappe-bench/sites/common_site_config.json
RUN chown frappe:frappe /home/frappe/frappe-bench/sites/common_site_config.json

ARG version=13
ENV frappe_path if [ $version -eq 13 ]; then echo 'https://github.com/alias/frappe'; else echo 'https://github.com/frappe/frappe'; fi
ENV frappe_branch if [ $version -eq 13 ]; then echo 'pcg-13-released'; else echo 'version-12'; fi

ADD https://api.github.com/repos/alias/frappe/git/refs/heads/pcg-13-released version.json
# RUN git ls-remote git://$(eval $frappe_path | sed 's|https://||g') | grep $(eval $frappe_branch) | cut -f 1 > ./frappe_version
# RUN cat ./frappe_version
RUN echo "bench init frappe-bench --python python3 --frappe-path=$(eval $frappe_path) --frappe-branch=$(eval $frappe_branch) --ignore-exist"
RUN su - frappe -c "bench init frappe-bench --python python3 --frappe-path=$(eval $frappe_path) --frappe-branch=$(eval $frappe_branch) --ignore-exist"
WORKDIR /home/frappe/frappe-bench/
RUN bash -c "source /home/frappe/frappe-bench/env/bin/activate && pip install -U pylint && pylint --generate-rcfile > ~/.pylintrc"
RUN bash -c "source /home/frappe/frappe-bench/env/bin/activate && pip install -U mypy"
RUN service mysql start && mysql mysql -e "SET PASSWORD FOR 'root'@'localhost' = PASSWORD('123'); flush privileges" && su frappe -c "bench new-site localhost"


# INSTALL VS_CODE
# touch to get new hash

RUN curl -fsSL https://code-server.dev/install.sh > code-server-install.sh && chmod +x ./code-server-install.sh && ./code-server-install.sh --version 3.6.2


# Fix  
# E: Repository 'http://security.debian.org buster/updates InRelease' changed its 'Suite' value from 'stable' to 'oldstable'
# E: Repository 'http://deb.debian.org/debian buster InRelease' changed its 'Suite' value from 'stable' to 'oldstable'
# from https://www.reddit.com/r/debian/comments/ca3se6/for_people_who_gets_this_error_inrelease_changed/
RUN apt-get --allow-releaseinfo-change update 

# Setup User Visual Studio Code Extentions
run apt-get --allow-releaseinfo-change update && apt-get install -y libarchive-tools graphviz
ENV VSCODE_USER "/home/coder/.local/share/code-server/User"
ENV VSCODE_EXTENSIONS "/home/frappe/.local/share/code-server/extensions"

# Set pythonevironment link into apps dir, for vscode to find it
RUN ln -s ../env apps/.env

# Setup Python Extension
# RUN mkdir -p ${VSCODE_EXTENSIONS}/python \
#    && curl -JLs https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-python/vsextensions/python/2020.5.86806/vspackage | bsdtar --strip-components=1 -xf - -C ${VSCODE_EXTENSIONS}/python extension

RUN apt-get install -y unzip
RUN mkdir -p  ${VSCODE_EXTENSIONS} && curl -L https://github.com/microsoft/vscode-python/releases/download/2021.7.1050252941/ms-python-release.vsix --output ${VSCODE_EXTENSIONS}/python.zip && cd ${VSCODE_EXTENSIONS} && unzip python.zip && mv extension python
# Setup VIM Extension
# RUN mkdir -p ${VSCODE_EXTENSIONS}/vim \
#     && curl -JLs https://marketplace.visualstudio.com/_apis/public/gallery/publishers/vscodevim/vsextensions/vim/latest/vspackage | bsdtar --strip-components=1 -xf - -C ${VSCODE_EXTENSIONS}/vim extension

# Setup Python Linting
# RUN echo "frappe" | sudo -S /home/frappe/frappe-bench/apps/.env/bin/python /home/frappe/.local/share/code-server/extensions/python/pythonFiles/pyvsc-run-isolated.py pip install pylint
# RUN echo "frappe" | sudo -S /home/frappe/frappe-bench/apps/.env/bin/python pip install pylint


# Change ownerships back to frappe, as this was installed as root user
RUN chown -R frappe:frappe /home/frappe/.local

# Setup Production Env
RUN sudo bench setup production --yes frappe 
RUN ln -s `pwd`/config/nginx.conf /etc/nginx/sites-enabled/frappe.conf
# RUN sed -i 's/8000/8001/g' config/supervisor.conf


USER frappe
WORKDIR /home/frappe/frappe-bench/
