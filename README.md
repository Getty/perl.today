PT.net / ClanID.net
=========================


Installation Development Environment
====================================

We use **Debian** systems for development, please use the same for your work.
Also everything we do, we do as user, no root access is ever required, if any
software tells you that you dont have enough rights, then this is an error and
not a reason to activate the root account. **NO ROOT**

Base environment
----------------

For assuring a unified environment we suggest to install an independent
environment via [Installer](https://metacpan.org/pod/installto) which will
assure that you use the identical version of the used supportive software.
You can do so via the web installation method of **Installer**. Execute this
command inside your checkout of the repository:

```
curl -L http://installer.pm/ | sh -s -- -f ~/usr/pt
```

This will download **Installer** as one perl executable from the net and uses
the **installer** file in the current directory to install to the given
directory. You can pick every directory you want, but you cant target into
your checkout or into the directory **~/pt**, as this will be later used
as file storage for the development environment.

**TEMPORARY WORKAROUND:** Sadly there is still a bug in **Installer** which
leads to a wrong produced **export.sh** in the environment directory, please
edit this file and assure that those lines are in it:

```
eval $( perl -I/home/username/usr/pt/perl5/lib/perl5 -Mlocal::lib=--deactivate-all )
eval $( perl -I/home/username/usr/pt/perl5/lib/perl5 -Mlocal::lib=/home/username/usr/pt/perl5 )

export PGDATA="/home/username/usr/pt/pgdata"
export PGPORT=16661
export PGHOST="localhost"

export PS1="\e[0;36m[\e[1;34mPT\e[0;36m]\e[0m $PS1"
```

After installation, you can activate the environment, via the following
command. You will see a little blue **[PT]** in front of your prompt
now.

```
. ~/usr/pt/export.sh
```

Perl requirements
-----------------

After activating the environment you can start installing the Perl
requirements for the project. This will take some time, but using other people
modules, assures that we can invest more time into the platform, instead of
reinventing the wheel over and over. Run the following commands inside your
checkout:

```
cpanm Dist::Zilla
dzil authordeps | cpanm
dzil listdeps --missing | cpanm
```

This will take more than an hour, depending on system. If an installation
fails you should read the log and see if you can fix it yourself, often it is
only a missing development library that needs to be installed on your system,
here you can actually use root then of course for those library requirements.

PostgreSQL
----------

**TEMPORARY WORKAROUND:** Normally the installation via **Installer** should
assure to setup the database, but this sadly is also part of the bug ;). Please
do the following to get your database:

```
initdb
pg_ctl start
createdb pt
pg_ctl stop
```

You can then, after activating the environment use the **start** and **stop**
commands to start and stop the PostgreSQL server of the environment.

Project environment variables
-----------------------------

Additional to the variables injected by the **export.sh**, you also will need
some environment variables for the project itself. You can add them by hand to
the **export.sh**, but as you might redo this at some point with a new
installation with **Installer** (where the bug is actually fixed), it could be
wise to use another file for this. Here are the variables which are relevant
for your development:

```
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

The SMTP settings are required for sending the emails for registration and
forgot password and everything else. They are not required to be set if your
system has a **sendmail** binary which actually can send out emails. You can
adjust the From of the email with the environment variable, but its optional,
by default i uses **noreply@pt.net**.

**TODO STEAM (not used yet)**

The web base setting is used in the context of emails, but is also relevant
for the Facebook related functionality, as it is used for the redirects and
also should be registered as URL for your Facebook application on Facebook.
You should make your own app and use its app id and secret here. This way
you can test on your own environment the facebook login and registration. Best
is to configure your local hosts file to use your development server IP as
host for this given web base, then facebook redirects you totally proper to
your development server. Its really simple to test, but be sure that you add
the right URL to the Facebook application.

The twitter consumer key and secret is used for login/registration via
Twitter.
