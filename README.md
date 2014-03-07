perl.today
==========

Installation Development Environment
====================================

Assuming you want to install the environment to /home/user/usr/pt

Installing postgresql:
```
~/src/postgresql-9.3.3$ ./configure --prefix=/home/user/usr/pt
~/src/postgresql-9.3.3$ make install
```

export.sh for environment:
```
export PATH="/home/user/usr/pt/bin:$PATH"
export LD_LIBRARY_PATH="/home/user/usr/pt/lib:$LD_LIBRARY_PATH"
export C_INCLUDE_PATH="/home/user/usr/pt/include:$C_INCLUDE_PATH"
export MANPATH="/home/user/usr/pt/man:$MANPATH"

export PGDATA="/home/user/usr/pt/pgdata"
export PGPORT=17375
export PGHOST="localhost"

export PS1="\e[0;36m[\e[1;31mperl.today\e[0;36m]\e[0m $PS1"

export PT_SMTP_HOST="mail.yourprovider.de"
export PT_SMTP_SSL="1"
export PT_SMTP_SASL_USERNAME="smtpusername"
export PT_SMTP_SASL_PASSWORD="smtppassword"
export PT_EMAIL_FROM="noreply@pt.net"
export PT_STEAM_WEB_API="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"     
export PT_WEB_BASE="http://pt.somedomain.de:3000"
export PT_FACEBOOK_APP_ID="111111111111111"
export PT_FACEBOOK_APP_SECRET="aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
export PT_TWITTER_CONSUMER_KEY="xxxxxxxxxxxxxxxxxxxxxx"
export PT_TWITTER_CONSUMER_SECRET="xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

After loading export.sh init DB for first time:

```
[perl.today] torsten@bigbird:~/usr/pt$ initdb
```
