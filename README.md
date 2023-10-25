
## Introduction

This is a recreation of the PySnow Library written in the bash script language using curl for requests.

## 🔥 Updates

- Create templates
- Filter search

## Syntax

```
$ snowbash -h
```

Syntax:

```
snowbash [-r|-m] [-c] [-q] [-s] [-p|-t] [-v|-h] | [-t|-i]
```

Options:

```
    -r (--record)
        records are a type of form or data in ServiceNow
    
    -q (--query)
        only return the data requested from a record
    
    -c (--change)
        modify an existing record either with -q or -p

    -s (--search)
        search record tables in ServiceNow ie. Linux, AIX
    
    -p (--payload)
        payload formatted in english but converted to json

    -m (--make)
        create a record type ie. INC or CHG with -p

    -t (--template)
        use a .template file as a substitute for -p
    
    -i (--insert)
        substitute data tags in a template to make unique

    -v (--version)
        display version information

    -h (--help)
        return help menu for command usage and examples

```

## Features

To truly take full advantage of ServiceNow, creating, modifying, viewing records are critical from an api.

### Create

- Create records (incidents, change requests, request items, ctasks, etc.) Ex.

```
# Create incident assigned to James with assigned group x return incident number:

$ snowbash -m INC -p "assigned_to=James Doe, assignment_group=, ..." -q number

--------------
INC######
```

### Modify

- Change key values in a record using a payload.

```
# Modify an incident by reassigning it to Cynthia:

$ snowbash -r INC###### -q assigned_to -c "Cynthia William"

--------------
assigned_to -> Cynthia William
```

### Search

- Search for records of a specific type with filters in ServiceNow readable fashion.

```
# Search in all linux servers for OS version 6* and return there names:

$ snowbash -s linux -p "os_version starts with 6 & install_status = 1" -q name

...
example-server07
example-server08
example-server09
...
 2573 results
```

### View

- Get the contents of particular information from any record including user, device, change, incident, etc.

```
# Get the cmdb device from a change request number:

$ snowbash -r CHG###### -q cmdb_ci

--------------
example-server
```

### Template and Inserts

- Use templates to automate the boring stuff by creating a file with all the information to create a record:

```
# Create a .template file with all the details for a change:

$ cat decom.template

--------------
# Change for decommissioning server(s):

record="CHG"
category="Operating System"
cmdb_ci="<HOST>"
requested_by="<ME>"
short_description="Retiring Server(s): <HOST>"
assigned_to="<ME>"
u_environment="<ENV>"
test_plan="..."
u_test_results="..."
justification="..."
start_date="<DATE>"
end_date="4"
work_notes="Created change from CLI Template!"
--------------
```

This template is unique in that it substitutes tags with any unique uppercase names. The default are ME, which uses your account name you execute with and searching it in ServiceNow. ENV uses the host name provided, and searches its environment in CMDB. Duration or end_date will add in hours to the date you provide.

```
# Create a change for example-server09 for the 21st August at 11:30 PM (imply current year)

$ snowbash -t decom -i "HOST=example-server09, DATE=08/21_2330"

--------------
CHG###### - example-server09
```

