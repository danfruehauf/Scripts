# check_sql

http://exchange.nagios.org/directory/Plugins/Databases/Others/check_sql/details

check_sql is a nagios plugin to check SQL queries using perl DBI.

check_sql is database agnostic and the support depends only on what DBI can support.

I've personally tested check_sql with the following:
 * MySQL
 * PostgreSQL
 * SQL Server

It should support also:
 * Oracle databases
 * SQLite
 * CSV
 * Many other databases I've never used :)

check_sql is based on work done by <b>Nagios Plugin Development Team</b> and <b>Thomas Guyot-Sionnest</b>, I've decided to inherit it and add generic DBI support. I promise to do my best to maintain it...

## Features

check_sql features the following:
 * Support any database supported by DBI
 * Run any query you'd like
 * Compare values returned in queries

## Simple Usage

	./check_sql -v -s -d DSN -U USERNAME -P PASSWORD -q "select count(*) from some_table"

DSN is the DBI connection string to connect to the database. Some examples:

	DBI:mysql:database=users;host=localhost;port=3306

	DBI:Pg:dbname=homes;host=localhost;port=5432

	DBI:Sybase:server=cakes:1433

Refer to the specific tutorial to find the right DSN for your DB.

## Plugin Specifics

### MySQL

You'll need the DBD::MySQL driver for that.

Example:

	./check_sql -v -s -d "DBI:mysql:database=DB_NAME;host=DB_HOSTNAME;port=DB_PORT" -U USERNAME -P PASSWORD -q "select count(*) from some_table"

### PostgreSQL

You'll need the DBD::Pg driver for that.

Example:

	./check_sql -v -s -d "DBI:Pg:dbname=DB_NAME" -U USERNAME -P PASSWORD -q "select count(*) from some_table"

### SQL Server

You'll need the DBD::Sybase driver for that.

Example:

	./check_sql -v -s -d DBI:Sybase:server=SERVER_NAME:PORT -U DB_USERNAME -P DB_PASSWORD -q "select count(*) from some_table"

### Limitations

Please open me issues if you find any. I promise to address them as soon as I can.
