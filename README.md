Just a few tools for Eve Online that I've written.  Nothing too special here.

Database Dumps
==============

CCP provides static data dumps in MSSQL format.  Since that can be difficult,
inconvenient, and/or depressing to use, some other people have provided MySQL
data dumps.  I won't get on my high horse about MySQL in a README file, but
suffice to say I appreciate their efforts.  I've made one such MySQL dump
available at the following URL.

[evedump.sql.bz2; 46 MB](http://www.colinwetherbee.com/eve/static/evedump.sql.bz2)

This data dump comes from db.descention.net and can be used with MySQL 5.1 and
up.  My favorite way to import it is the following.

    # echo 'create database evedump;' | mysql
    # bzip2 -cd evedump.sql.bz2 | mysql evedump

