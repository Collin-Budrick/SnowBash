#!/bin/bash

shopt -s expand_aliases
shopt -s nocasematch

source ~/functions.sh

alias rrsh='rosh -l root -n '


instance='truist'
base_url="https://$instance.service-now.com/api/now"
sysparm_display='?sysparm_display_value=true&'
SHORT=r:,q:,c:,s:,f:,i:,p:,m:,t:,v,h
LONG=record:,query:,change:,search:,field:,insert:,payload:,make:,template:,version,help
OPTS=$(getopt -a -n request --options $SHORT --longoptions $LONG -- "$@")
group='ITSM-Ops-AIX'
field='number'
me=$(whoami)
eval set -- "$OPTS"

while :
do
  case "$1" in
    # Supply a record to modify or view the contents of
    -r | --record)
        record="$2"
        shift 2 ;;
    # Query the record from response
    -q | --query)
        query="$2"
        shift 2 ;;
    # Change query result with a single value
    -c | --change)
        change="$2"
        shift 2 ;;
    # Search any number of records from search criteria (needs --query)
    -s | --search)
        search="$2"
        shift 2 ;;
    # Change default field to query in (not often needed)
    -f | --field)
        field="$2"
        shift 2 ;;
    # Change default template values to found placeholders
    -i | --insert)
        insert="$2"
        shift 2 ;;
    # Change a record with multiple new values (needs --make, --record, or --search)
    -p | --payload)
        payload="$2"
        shift 2 ;;
    # Create a new record (needs a payload of values)
    -m | --make)
        make="$2"
        shift 2 ;;
    # Use a template instead of a payload which takes in a file of predefined values
    -t | --template)
        template="$2"
        shift 2 ;;
    # Shows version of BashSnow utility
    -v | --version)
        echo -e "BashSnow - 2.7 (Beta Release)\nUpdated: 10/7/2023"
        exit 0 ;;
    # Help menu
    -h | --help)
        largs=$(echo "$LONG" | tr ':,' '\n')
        echo -e "Syntax:\n\n\tapi -r <record> -q <query> -c <change> [--help]"
        echo
        echo -e "Options:\n"
        for i in $largs; do
            echo -e "\t--$i";
        done
        echo
        cat /home/g02613s/template/help.doc
        exit 0 ;;
    --)
        shift;
        break ;;
    *)
        echo "Unexpected option: $1"
        exit 2 ;;
  esac
done



if [ ! -z "$record" ]; then
    check_prefix $record
elif [ ! -z "$make" ]; then
    check_prefix $make
elif [ ! -z "$search" ]; then
    if [ "$search" = "cmdb" ]; then
        api_path="/table/cmdb_ci"
    elif [ "$search" = "linux" ]; then
        api_path="/table/cmdb_ci_linux_server"
    elif [ "$search" = "aix" ]; then
        api_path="/table/cmdb_ci_aix_server"
    else 
        check_prefix $search
    fi
elif [ -z "$search" ]; then
    api_path="/table/$search"
fi

start_url=$base_url
init_url=$base_url
params="sysparm_query=$field%3D$record"
base_url=$base_url$api_path
path=$base_url$sysparm_display$params

# Modify a single value in an existing record
if [ ! -z "$record" ] && [ ! -z $query ] && [ ! -z "$change" ]; then
    SnowChange $base_url "{'$query':'$change'}"
    echo -e "$query -> $change"

# Modify an existing record with a payload provided
elif [ ! -z "$record" ] && [ ! -z "$payload" ]; then
    output=$(echo $payload | sed "s/=/\t->\t/g" | sed "s/,/\n\t/g")
    PayloadFormat "$payload"
    SnowChange "$base_url" "$payload"
    echo -e "Changed:\n\t$output"

# Create a new record with a payload, and return a query in that new record
elif [ ! -z $make ] && [ ! -z "$payload" ] && [ ! -z "$query" ]; then
    output=$(echo $payload | sed "s/=/\t->\t/g" | sed "s/,/\n\t/g")
    PayloadFormat "$payload"
    SnowCreate "$base_url" "$payload" "$query"
    echo -e "$result"

# Create a new record from a template, and return a query in that new record
elif [ ! -z "$template" ] && [ ! -z "$insert" ]; then
    SnowTemplatePayload "$template" "$insert"
    #echo -e "$final"  # <<-- used for debugging
    #SnowCreate "$init_url" "$final" "number"
    #echo -e "$result - $host"
    
    # Adding in ctask creation:
    #stout=$(rrsh "$host" -t "$command") && echo -e "$stout" && SnowChange "$base_url" "{'work_notes':'can opener'}"

    record="CHG0690113"

    SnowSysID $record $init_url "sys_id"

    echo $result


    full=$(echo "$start_url/table/task_ci?sysparm_query=task%3D$result")

    data=$(echo "{'ci_item':'ite-pudecdt01','task':'$result'}")
    
    full=$(echo "$full")
    echo "$full"
    echo "$data"

    SnowPOST "$full" "$data"


# Search any number of records from search criteria contained in payload
elif [ ! -z "$search" ] && [ ! -z "$payload" ] && [ ! -z "$query" ]; then
    
    SnowSearch "$base_url" "$payload" "$query"
    num_results="$(echo -e "$result" | wc -l)"
    echo -e "$result\n $num_results results"





# Return a single value from a record
elif [ ! -z "$record" ] && [ ! -z $query ]; then
    SnowGet $path $query
    echo -e $result

# Return all available data in a record
elif [ ! -z "$record" ]; then
    echo -e "result"
    get $path | tr ',' '\n' | tr '"' ' ' | tr -d '}]}\{' | sed 's/result :\[ //g' | sed 's/ : /\t/g' | awk '{printf "\n\t" $1 "\n\t -> " $2 " -> " $3}' | sed 's/:null//g' 
    echo

# Return an error message stating the user is missing a mandatory flag
else
    echo "Error: You're missing a mandatory argument: either (--make), (--record), or (--query) is missing."
    exit 2
fi
exit 0
