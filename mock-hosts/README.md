# mock-hosts.sh

A few simple functions to mock entries in `/etc/hosts` mainly for the purpose of
testing.

***BACKUP YOUR /etc/hosts*** - I take no responsibility for any data loss.

You will need sudo access (duh!) to modify `/etc/hosts`.

## Simple Usage

In your `.bashrc` add a line that'll inclue `mock-hosts.sh` like:
```
source /home/dan/mock-hosts.sh
```

### Add A Mocked Host

```
$ add_mock_host 192.168.1.1 google.com www.google.com
```

Now `google.com` and `www.google.com` should resolve to `192.168.1.1`:
```
$ ping google.com
PING google.com (192.168.1.1) 56(84) bytes of data.

ping www.google.com
PING google.com (192.168.1.1) 56(84) bytes of data.
```

### Remove A Mocked Host

Using the IP address:
```
$ del_mock_host 192.168.1.1
```

Alternatively you can use the name of the service you mocked:
```
del_mock_host google.com
```

### Clear All Mocks

```
clear_mock_hosts
```

You shouldn't have any rubbish in your `/etc/hosts` now.

### Show All Mocks

```
$ show_mock_hosts 
---
192.168.2.1 google.com www.google.com ___MOCKED___
192.168.1.1 google.com www.google.com ___MOCKED___
---
```

## Internals

This set of functions just modifies `/etc/hosts` in such a way that it adds a
```___MOCKED___``` signature in the end of any line it mocks and makes the best
to deal just with those lines when modifying `/etc/hosts`.
