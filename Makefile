#
#  Author: Hari Sekhon
#  Date: 2013-02-03 10:25:36 +0000 (Sun, 03 Feb 2013)
#
#  https://github.com/harisekhon/nagios-plugins
#

ifdef TRAVIS
	SUDO2 =
	CPANM = cpanm
else
	SUDO2 = sudo
	CPANM = /usr/local/bin/cpanm
endif

# EUID /  UID not exported in Make
# USER not populated in Docker
ifeq '$(shell id -u)' '0'
	SUDO =
	SUDO2 =
else
	SUDO = sudo
endif

.PHONY: make
make:
	if [ -x /usr/bin/apt-get ]; then make apt-packages; fi
	if [ -x /usr/bin/yum ];     then make yum-packages; fi
	
	git submodule init
	git submodule update

	cd lib && make

	# There are problems with the tests for this module dependency of Net::Async::CassandraCQL, forcing install works and allows us to use check_cassandra_write.pl
	#sudo cpan -f IO::Async::Stream

	# XXX: there is a bug in the Readonly module that MongoDB::MongoClient uses. It tries to call Readonly::XS but there is some kind of MAGIC_COOKIE mismatch and Readonly::XS errors out with:
	#
	# Readonly::XS is not a standalone module. You should not use it directly. at /usr/local/lib64/perl5/Readonly/XS.pm line 34.
	#
	# Workaround is to edit Readonly.pm and comment out line 33 which does the eval 'use Readonly::XS';
	# On Linux this is located at:
	#
	# /usr/local/share/perl5/Readonly.pm
	#
	# On my Mac OS X Mavericks:
	#
	# /Library/Perl/5.16/Readonly.pm

	# Required to successfully build the MongoDB module for For RHEL 5
	#sudo cpan Attribute::Handlers
	#sudo cpan Params::Validate
	#sudo cpan DateTime::Locale DateTime::TimeZone
	#sudo cpan DateTime

	# You may need to set this to get the DBD::mysql module to install if you have mysql installed locally to /usr/local/mysql
	#export DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH:/usr/local/mysql/lib/"

	@#@ [ $$EUID -eq 0 ] || { echo "error: must be root to install cpan modules"; exit 1; }
	@# putting modules one per line just for ease of maintenance
	#
	# add -E to sudo to preserve http proxy env vars or run this manually if needed (only works on Mac)
	# Redis module required but didn't auto-pull: ExtUtils::Config ExtUtils::Helpers ExtUtils::InstallPaths TAP::Harness::Env Module::Build::Tiny Sub::Name
	# Kafka module required but didn't auto-pull: ExtUtils::Config, ExtUtils::Helpers, ExtUtils::InstallPaths, TAP::Harness::Env, Module::Build::Tiny, Sub::Exporter::Progressive, Const::Fast, Exporter::Tiny, List::MoreUtils, Devel::CheckLib, Compress::Snappy, Sub::Name
	# Module::CPANfile::Result and Module::Install::Admin are needed for Hijk which is auto-pulled by Search::Elasticsearch but doesn't auto-pull Module::CPANfile::Result
	# Module::Build::Tiny and Const::Fast must be built before Kafka, doesn't auto-pull in correct order
	# Proc::Daemon needed by Kafka::TestInternals
	# Proc::Daemon fails on tests, force install anyway to appease Travis
	yes "" | $(SUDO2) cpan App::cpanminus
	which cpanm || :
	yes "" | $(SUDO2) $(CPANM) --notest \
		YAML \
		Module::Build::Tiny \
		Const::Fast \
		Class::Accessor \
		Compress::Snappy \
		Proc::Daemon \
		DBD::mysql \
		DBI \
		Data::Dumper \
		Devel::CheckLib \
		Digest::Adler32 \
		Digest::CRC \
		Digest::MD5 \
		Digest::SHA \
		Digest::SHA1 \
		Exporter::Tiny \
		ExtUtils::Config \
		ExtUtils::Constant \
		ExtUtils::Helpers \
		ExtUtils::InstallPaths \
		IO::Socket::IP \
		IO::Socket::SSL \
		JSON \
		JSON::XS \
		Kafka \
		LWP::Authen::Negotiate \
		LWP::Simple \
		LWP::UserAgent \
		List::MoreUtils \
		Math::Round \
		Module::CPANfile::Result \
		Module::Install::Admin \
		MongoDB \
		MongoDB::MongoClient \
		Net::DNS \
		Net::LDAP \
		Net::LDAPI \
		Net::LDAPS \
		Net::SSH::Expect \
		Readonly \
		Readonly::XS \
		Search::Elasticsearch \
		SMS::AQL \
		Sub::Exporter::Progressive \
		Sub::Name \
		TAP::Harness::Env \
		Test::SharedFork \
		Thrift \
		Time::HiRes \
		Type::Tiny::XS \
		URI::Escape \
		XML::SAX \
		XML::Simple \
		;
	# newer versions of the Redis module require Perl >= 5.10, this will install the older compatible version for RHEL5/CentOS5 servers still running Perl 5.8 if the latest module fails
	# the backdated version might not be the perfect version, found by digging around in the git repo
	$(SUDO2) $(CPANM) Redis || $(SUDO2) $(CPANM) DAMS/Redis-1.976.tar.gz
		#Net::Async::CassandraCQL \
	
	# newer version of setuptools (>=0.9.6) is needed to install cassandra-driver
	# might need to specify /usr/bin/easy_install or make /usr/bin first in path as sometimes there are version conflicts with Python's easy_install
	$(SUDO) easy_install -U setuptools
	$(SUDO) easy_install pip || :
	# cassandra-driver is needed for check_cassandra_write.py + check_cassandra_query.py
	$(SUDO) pip install cassandra-driver scales blist lz4 python-snappy
	
	# install MySQLdb python module for check_logserver.py / check_syslog_mysql.py
	# fails if MySQL isn't installed locally
	$(SUDO) pip install MySQL-python
	@echo
	@echo BUILD SUCCESSFUL


.PHONY: apt-packages
apt-packages:
	$(SUDO) apt-get update
	# needed to fetch and build CPAN modules and fetch the library submodule at end of build
	$(SUDO) apt-get install -y build-essential libwww-perl git
	# for DBD::mysql as well as headers to build DBD::mysql if building from CPAN
	$(SUDO) apt-get install -y libdbd-mysql-perl libmysqlclient-dev
	# needed to build Net::SSLeay for IO::Socket::SSL for Net::LDAPS
	$(SUDO) apt-get install -y libssl-dev
	# for XML::Simple building
	$(SUDO) apt-get install -y libexpat1-dev
	# for check_whois.pl
	$(SUDO) apt-get install -y jwhois
	# for LWP::Authenticate
	#apt-get install -y krb5-config # prompts for realm + KDC, use libkrb5-dev instead
	$(SUDO) apt-get install -y libkrb5-dev
	# for Cassandra's Python driver
	$(SUDO) apt-get install -y python-setuptools python-dev libev4 libev-dev libsnappy-dev
	# HiveServer2
	$(SUDO) pip install pyhs2

.PHONY: yum-packages
yum-packages:
	rpm -q gcc gcc-c++ perl-CPAN perl-libwww-perl wget tar || $(SUDO) yum install -y gcc gcc-c++ perl-CPAN perl-libwww-perl wget tar
	# for DBD::mysql as well as headers to build DBD::mysql if building from CPAN
	rpm -q perl-DBD-MySQL mysql-devel || $(SUDO) yum install -y perl-DBD-MySQL mysql-devel
	# needed to build Net::SSLeay for IO::Socket::SSL for Net::LDAPS
	rpm -q openssl-devel || $(SUDO) yum install -y openssl-devel
	# for XML::Simple building
	rpm -q expat-devel || $(SUDO) yum install -y expat-devel
	# for check_whois.pl
	rpm -q jwhois || $(SUDO) yum install -y jwhois
	# for Cassandra's Python driver
	# python-pip requires EPEL, so try to get the correct EPEL rpm - for Make must escape the $3
	# this doesn't work for some reason CentOS 5 gives 'error: skipping https://dl.fedoraproject.org/pub/epel/epel-release-latest-5.noarch.rpm - transfer failed - Unknown or unexpected error'
	# must instead do wget 
	#$(SUDO) rpm -ivh "https://dl.fedoraproject.org/pub/epel/epel-release-latest-`awk '{print substr($$3, 0, 1); exit}' /etc/*release`.noarch.rpm"
	rpm -q epel-release || { wget -O /tmp/epel.rpm "https://dl.fedoraproject.org/pub/epel/epel-release-latest-`awk '{print substr($$3, 0, 1); exit}' /etc/*release`.noarch.rpm" && $(SUDO) rpm -ivh /tmp/epel.rpm; }
	rm /tmp/epel.rpm || :
	# only available on EPEL in CentOS 5
	rpm -q git || $(SUDO) yum install -y git
	rpm -q python-setuptools python-pip python-devel libev libev-devel snappy-devel || $(SUDO) yum install -y python-setuptools python-pip python-devel libev libev-devel snappy-devel
	# to fetch ZooKeeper
	rpm -q wget || yum install -y wget
	# needed to build pyhs2
	# libgsasl-devel saslwrapper-devel
	rpm -q cyrus-sasl-devel || $(SUDO) yum install -y cyrus-sasl-devel
	# for check_yum.pl / check_yum.py
	yum install -y yum-security yum-plugin-security


# Net::ZooKeeper must be done separately due to the C library dependency it fails when attempting to install directly from CPAN. You will also need Net::ZooKeeper for check_zookeeper_znode.pl to be, see README.md or instructions at https://github.com/harisekhon/nagios-plugins
# doesn't build on Mac < 3.4.7 / 3.5.1 / 3.6.0 but the others are in the public mirrors yet
# https://issues.apache.org/jira/browse/ZOOKEEPER-2049
ZOOKEEPER_VERSION = 3.4.7
.PHONY: zookeeper
zookeeper:
	[ -x /usr/bin/apt-get ] && make apt-packages || :
	[ -x /usr/bin/yum ]     && make yum-packages || :
	[ -f zookeeper-$(ZOOKEEPER_VERSION).tar.gz ] || wget -O zookeeper-$(ZOOKEEPER_VERSION).tar.gz http://www.mirrorservice.org/sites/ftp.apache.org/zookeeper/zookeeper-$(ZOOKEEPER_VERSION)/zookeeper-$(ZOOKEEPER_VERSION).tar.gz
	[ -d zookeeper-$(ZOOKEEPER_VERSION) ] || tar zxvf zookeeper-$(ZOOKEEPER_VERSION).tar.gz
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/c; 				./configure
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/c; 				make
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/c; 				$(SUDO) make install
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/contrib/zkperl; 	perl Makefile.PL --zookeeper-include=/usr/local/include/zookeeper --zookeeper-lib=/usr/local/lib
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/contrib/zkperl; 	LD_RUN_PATH=/usr/local/lib make
	cd zookeeper-$(ZOOKEEPER_VERSION)/src/contrib/zkperl; 	$(SUDO) make install
	perl -e "use Net::ZooKeeper"


.PHONY: test
test:
	cd lib && make test
	# doesn't return a non-zero exit code to test
	# for x in *.pl; do perl -T -c $x; done
	# TODO: add more functional tests back in here
	tests/help.sh

.PHONY: install
install:
	@echo "No installation needed, just add '$(PWD)' to your \$$PATH and Nagios commands.cfg"

.PHONY: update
update:
	make update2
	make

.PHONY: update2
update2:
	git pull
	git submodule update --init

.PHONY: clean
clean:
	rm -fr zookeeper-$(ZOOKEEPER_VERSION).tar.gz zookeeper-$(ZOOKEEPER_VERSION)
