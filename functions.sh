#!/bin/bash

shopt -s expand_aliases
shopt -s nocasematch

alias get='curl -s -k --netrc-file ~/.secrets.txt -H "Content-Type: application/json" -H "Accept: application/json"'

alias modify='curl -s -k -X PATCH --netrc-file ~/.secrets.txt -H "Content-Type: application/json" -H "Accept: application/json" -d'

alias create='curl -s -k -X POST --netrc-file ~/.secrets.txt -H "Content-Type: application/json" -H "Accept: application/json" -d'

# Library Functions for script integration:
function SnowLink {
    instance=$1
    table=$2
    display_values="$3"

    if [ $display_values == "ALL" ]; then
        link="https://$1.service-now.com/api/now$2?sysparm_query=active?sysparm_display_value=all"
    else
        link="https://$1.service-now.com/api/now$2"
    fi
    
    return 0
}


function SnowPOST {
    url=$1
    payload=$2
    raw_result=$(create "$payload" $url)
    
    echo $raw_result

}

# Building out a url to search by substituting english with its url string:
function SnowQuery {
    url=$1
    conjunction=$2
    field=$3
    operator=$4
    value=$5

    if [ $conjunction == "and" ]; then
        conjunction="%5E"
    elif [ $conjunction == "or" ]; then
        conjunction="%5EOR"
    else
        echo "Not a valid operator. Try and/or"
    fi

    if [ $operator == "equals" ]; then
        operator="%3D"

    elif [ $operator == "not_equal" ]; then
        operator="!%3D"

    elif [ $operator == "starts_with" ]; then
        operator="STARTSWITH"

    elif [ $operator == "Scripts" ]; then
        operator="STARTSWITH"
    
    else
        echo "Not a valid search method OR not build into system yet. Contact Collin Budrick if an operator is missing that you would like to add."
    fi
    link="$url$conjunction$field$operator$value"

    return 0
}


function SnowSysID {
    record=$1
    base_url=$2
    filter=$3
    result=$(get "$base_url?sysparm_query=number%3D$record&sysparm_fields=$filter" | sed "s/result//g" | sed "s/$filter//g" | tr -d '\"\:\{\}\]\[' | sed 's/display_value//g' | tr ':' '\n' | tr ',' '\n')
}

# Search ServiceNow with a english written payload:
function SnowSearch {
    url=$1
    payload=$2
    query=$3

    # echo
    # echo -e "$payload"
    # payload=$(echo "'$payload'" | tr " " "#" | sed "s/#&#/ & /g")


    # for i in $payload; do
    #     if [[ "$i" = *"contain"* ]]; then

    #         contains=$(echo "$i" | tr -d "'")
            

    #         contains=$(echo "$contains" | tr "#" " ")

    #         #echo "$contains"

    #         loop_contain=$(echo "$contains" | awk '{print $1" "$2" "$3" "$4}')

    #         #echo "$loop_contain"
    #         echo
    #         new_contains=$(echo "$contains" | sed "s/, /#$loop_contain#/g" | tr -d ",")
    #         echo "$contains -> $new_contains"
    #         echo
    #         payload=$(echo "$payload" | sed "s/$contains/$new_contains/g")
    #     fi
    # done
    # echo
    
    # #payload=$(echo "$payload" | tr "#" " " )
    # echo "$payload"

    payload=$(echo -e "%5E$payload" | sed "s/ & /%5E/g" | sed "s/ || /%5EOR/g" | sed "s/ = /%3D/g" | sed "s/ isnt /!%3D/g" | sed "s/ empty /ISEMPTY/g" | sed "s/ like /LIKE/g" | sed "s/ starts with /STARTSWITH/g" | sed "s/ doesnt contain /NOT%20LIKE/g" | tr -d ' ')

    # echo

    # echo -e "$payload"
    #echo
    #=echo "$url?sysparm_query=active?sysparm_display_value=all$payload&sysparm_fields=$query"
    
    result=$(get "$url?sysparm_query=active?sysparm_display_value=all?display_value=true$payload&sysparm_fields=$query" | sed "s/result//g" | sed "s/$query//g" | tr -d '\"\:\{\}\]\[' | sed 's/linkhttps.*//g' | sed 's/display_value//g' | tr ':' '\n' | tr ',' '\n' )

    return 0
}
# 

# Get a curl response from the link provided and filter to particular data. (ie. number, name)
function SnowGet {
    sysparm_display='?sysparm_display_value=true'
    url=$1
    filter=$2
    result=$(get "$url&sysparm_fields=$filter" | sed "s/result//g" | sed "s/$filter//g" | tr -d '\"\:\{\}\]\[' | sed 's/display_value//g' | tr ':' '\n' | tr ',' '\n')
    
    return 0
}

# Create a new record using a payload of data, once done, return data from the new record.
function SnowCreate {
    url=$1
    payload=$2
    query=$3
    raw_result=$(create "$payload" $url)
    
    if [ -z $query ]; then
        query="number"
    else
        query=$3
    fi

    #echo -e $raw_result
    result=$(echo -e $raw_result | tr ',' '\n' | sed "s/result//g" | grep $query | sed "s/$query//g" | tr -d '\"\:\{\}\]\[' | sed 's/display_value//g' | head -n 1)
    return 0
}

# Change a record with curl from the link and a payload (i.e: "{'assigned_to':'Collin Budrick'}")
function SnowChange {
    url=$1
    payload=$2
    path="$url?$params"
    sysparm_display='?sysparm_display_value=true&'
    SnowGet "$path" 'sys_id'
    path1=$1/$result
    modify "$payload" $path1 &>/dev/null
    return 0
}

# Reformat payload to json: "assigned_to=Collin Budrick,category=3" to "{'assigned_to':'Collin Budrick','category':'server'}"
function PayloadFormat {
    payload=$(echo -e "{'$1'}" | sed "s/=/\':\'/g" | sed "s/, /\',\'/g" )
}

# Checks a prefix to see what api table it belongs to:
function check_prefix {
    key=$1
    if [ -z $key ]; then
        exit 1
    elif [[ $key = INC* ]]; then
        api_path='/table/incident'
    elif [[ $key = CHG* ]]; then
        api_path='/table/change_request'
    elif [[ $key = RITM* ]]; then
        api_path='/table/sc_req_item' #sc_req_item
    elif [[ $key = REQ* ]]; then
        api_path='/table/sc_request'
    elif [[ $key = STASK* ]]; then
        api_path='/table/sc_task'
    elif [[ $key = *s ]]; then
        api_path='/table/sys_user'
        field='user_name'
    else
        api_path='/table/cmdb_ci'
        field='name'
    fi
}


function SnowReturn {
    url=$1
    filter=$2
    result=$(get "$url" | sed "s/result//g" | sed "s/$filter//g" | tr -d '\"\:\{\}\]\[' | sed 's/display_value//g' | tr ':' '\n' | tr ',' '\n')

}

# Return data about a user from their s account:
function SnowUser {
    user="$1"
    info="$2"
    path="https://truist.service-now.com/api/now/table/sys_user?sysparm_display_value=true&sysparm_query=user_name%3D$user"
    SnowGet $path $info
}

# Return data about a server from CMDB record:
function SnowServer {
    host="$1"
    info="$2"
    path="https://truist.service-now.com/api/now/table/cmdb_ci?sysparm_display_value=true&sysparm_query=name%3D$host"
    SnowGet $path $info
}

# Converts a template to a readable payload for ServiceNow (& Logic handling):
function SnowTemplatePayload {
    template="$1"
    insert="$2"
    output=$(cat  ~/$template.txt | tr " " "$" )

    # Loops over all lines in a template, assigns variables for values = keys pairs:
    for i in $output; do

        value_pair=$(echo "$i" | tr -d "\"")
        template_value=${value_pair%=*}
        template_key=${value_pair#*=}
        
        # Detect if a value is "record," check key, & modify api path accordingly:
        if [ $template_value = "record" ]; then
            check_prefix $template_key
            output=$(echo -e $output | sed "/$template_value/d")
            init_url=$init_url$api_path
        
        # Detect if a key includes <ME> & substitute it with the full name provided in CMDB:
        elif [ $template_key = "<ME>" ]; then
            SnowUser $me "name"
            template_key=$(echo -e "$template_key" | sed "s/$template_key/$result/g" )
            final=$(echo -e "$final\n'$template_value=$template_key'\n" | tr "$" " " )

        # Detect if a key is command & save it for processing: 
        elif [ $template_value = "command" ]; then
            command=$(echo -e "$template_key" | tr "$" " ")

            # Add in multi-processing here for remote command execution <-------------------------

        # Detect if a value is "start_date," & reformat the provided DATE:
        elif [ $template_value = "start_date" ]; then
            for e in $insert; do
                substitute=$(echo -e "$e" | tr "_" " " | tr -d ",")
                sub_value=${substitute%=*}
                sub_replace=${substitute#*=}
                year=$(date +%Y)

                # Detect if the user specified a date for the start_data and format accordingly:
                if [ $sub_value = "DATE" ]; then

                    date=$(echo -e "$sub_replace" | sed "s/ /\/$year /g" | awk '{print $1}')
                    times=$(echo -e "$sub_replace" | awk '{print $2}' | sed "s/../&:/g; s/:$//")
                    start_date=$(echo -e "$date $times:00")

                    # Add 4h to provided date because ServiceNow reads a dates in UTC:
                    start_date=$(date -d "$start_date 4 hours" +"%m/%d/%Y %H:%M:%S")

                    final=$(echo -e "$final\n'$template_value=$start_date'\n" | tr "$" " ")
                
                # Swap Host in the template for the user provided, and grab the environment from CMDB:
                elif [ $sub_value = "HOST" ]; then
                    SnowServer $sub_replace "environment"
                    env=$(echo "$result" | tr -d " " | sed "s/null//g")
                    final=$(echo -e $final | sed "s/<ENV>/$env/g")
                    final=$(echo -e $final | sed "s/<$sub_value>/$sub_replace/g")
                
                # Substitute any unique tags with user completion provided:
                else
                    final=$(echo -e $final | sed "s/<$sub_value>/$sub_replace/g")
                fi
            done
        
        # Detect if a value is "end_date," add its key (duration) to the "start_date" & format:
        elif [ $template_value = "end_date" ]; then
            end_date=$(date -d "$start_date $template_key hours" +"%m/%d/%Y %H:%M:%S")
            final=$(echo -e "$final\n'$template_value=$end_date'\n" | tr "$" " " )
        
        # Omit comments from payload:
        elif [[ $i = \#* ]] ; then
            :

        # Assume other keys/values, and add them to final:
        else
            final=$(echo -e "$final\n'$template_value=$template_key'\n" | tr "$" " " )

        fi
    done

    #echo "$final"      # Debug (print before json formatting)
    
    # Convert to a json format, remove newlines, spaces, and etc:
    final=$(echo -e $final | tr '\n' ",")
    final=$(echo -e "{'$final'}" | sed "s/=/\':\'/g" | sed "s/,/\',\'/g" | sed "s/,''}/}/g" | sed "s/' '/','/g" | sed "s/''/'/g" )

    #echo "$final"
}
