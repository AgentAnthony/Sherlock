#!/usr/bin/env bash
# Author: Gilles Biagomba
# Program: Sherlock.sh
# Description: This script is designed to automate the earlier phases.\n
#              of a web application assessment (specficailly recon).\n

# for debugging purposes
# set -eux
trap "echo Booh!" SIGINT SIGTERM

# Checking if the user is root
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Checking if running the latest version
# curl --connect-timeout 5 -s https://api.github.com/repos/gbiagomba/Sherlock/tags | grep -eo '^(\d+\.)?(\d+\.)?(\*|\d+)$'| head -1 | cut -c11-13
# https://www.regextester.com/95064

# Declaring variables
current_time=$(date "+%Y.%m.%d-%H.%M.%S")
pth=$(pwd)
wrkpth="$PWD/Sherlock"
API_AK="" #Tenable Access Key
API_SK="" #Tenable Secret Key
NMAP_SCRIPTARG="newtargets,userdb=/usr/share/seclists/Usernames/cirt-default-usernames.txt,passdb=/usr/share/seclists/Passwords/cirt-default-passwords.txt,unpwdb.timelimit=15m,brute.firstOnly"
NMAP_SCRIPTS="vulners,vulscan/vulscan.nse"
OS_CHK=$(cat /etc/os-release | grep -o debian)
WORDLIST="/usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt"
diskMax=95
diskSize=$(df | grep /dev/sda1 | cut -d " " -f 13 | cut -d "%" -f 1)
targets=$1
prj_name=$2
wrktmp=$(mktemp -d)
IPv6=$(rg --engine -i -o -e "(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))" 2> /dev/null | grep -iv "FE80:" | cut -d ":" -f 2-9 | sort | uniq)

# Functions
function Banner
{
    echo
    echo "--------------------------------------------------"
    echo "$1
    Current Time : $current_time"
    echo "--------------------------------------------------"
}

# https://bytefreaks.net/gnulinux/bash/convertandprintseconds-convert-seconds-to-minutes-hours-and-days-in-bash
convertAndPrintSeconds() 
{
    # local totalSeconds=$1;
    # local seconds=$((totalSeconds%60));
    # local minutes=$((totalSeconds/60%60));
    # local hours=$((totalSeconds/60/60%24));
    # local days=$((totalSeconds/60/60/24));
    # (( $days > 0 )) && printf '%d days ' $days;
    # (( $hours > 0 )) && printf '%d hours ' $hours;
    # (( $minutes > 0 )) && printf '%d minutes ' $minutes;
    # (( $days > 0 || $hours > 0 || $minutes > 0 )) && printf 'and ';
    # printf '%d seconds\n' $seconds;
        num=$1
    min=0
    hour=0
    day=0
    if((num>59));then
        ((sec=num%60))
        ((num=num/60))
        if((num>59));then
            ((min=num%60))
            ((num=num/60))
            if((num>23));then
                ((hour=num%24))
                ((day=num/24))
            else
                ((hour=num))
            fi
        else
            ((min=num))
        fi
    else
        ((sec=num))
    fi
    echo "$day"d "$hour"h "$min"m "$sec"s
}

# Ensuring system is debian based
if [ "$OS_CHK" != "debian" ]; then
    echo "Unfortunately this install script was written for debian based distributions only, sorry!"
    exit
fi

# Checking system resources (HDD space)
if [[ "$diskSize" -ge "$diskMax" ]]; then
	clear
	echo 
	echo "You are using $diskSize% and I am concerned you might run out of space"
	echo "Remove some files and try again, you will thank me later, trust me :)"
	exit
fi

# Setting Envrionment
for i in Batea DNS_Recon EyeWitness GOLismero Halberd Harvester Masscan Metagoofil Nikto Nmap PathEnum SSH SSL SubDomainEnum Wappalyzer WebVulnScan XSStrike l00tz; do
    if [ ! -e $wrkpth/$i ]; then
        mkdir -p $wrkpth/$i
    fi
done

# Loadfing in support scripts
source gift_wrapper.sh

# Starting services
service postgresql start
service docker start

{
# Moving back to original workspace & loading logo
cd $pth
echo "
 _____  _               _            _    _ 
/ ____ | |             | |          | |  | |
| (___ | |__   ___ _ __| | ___   ___| | _| |
\___  \| '_ \ / _ \ '__| |/ _ \ / __| |/ / |
____)  | | | |  __/ |  | | (_) | (__|   <| |
|_____/|_| |_|\___|_|  |_|\___/ \___|_|\_(_)
"
echo "Web app scanning? Elementary my dear $USER!"
echo

# Requesting target file name or checking the target file exists & requesting the project name
if [ -z $targets ]; then
    echo "What is the name of the targets file? The file with all the IP addresses or sites"
    read targets
    echo

    if [ ! -r $targets ]; then
        echo "File not found! Try again!"
        exit
    fi
fi

if [ -z $prj_name ]; then
    echo "What is the name of the project?
    Leave blank and hit enter if you do not have one"
    read prj_name
    echo

    if [ -z $prj_name ]; then
        prj_name=$RANDOM
    fi
fi

# Recording screen output
# exec >|$PWD/$prj_name-term_output.log 2>&1

# Parsing the target file
cat $pth/$targets | grep -E "(\.gov|\.us|\.net|\.com|\.edu|\.org|\.biz|\.io|\.info|\.tv)" > $wrktmp/WebTargets
cat $pth/$targets | rg --engine -i -o -e "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" > $wrktmp/TempTargets
cat $pth/$targets | grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\/[0-9]\{1,\}'  >> $wrktmp/TempTargets
cat $pth/$targets | $IPv6 >> $wrktmp/TempTargetsv6
cat $wrktmp/TempTargets | sort | uniq > $wrktmp/IPtargets
cat $wrktmp/TempTargetsv6 | sort | uniq > $wrktmp/IPtargetsv6
echo

# Using sublist3r 
Banner "Performing Subdomain enum"
# consider replacing with  gobuster -m dns -o gobuster_output-$current_time.txt -u example.com -t 50 -w "/usr/share/dirbuster/wordlists/directory-list-2.3-medium.txt"
# gobuster -m dns -cn -e -i -r -t 25 -w $WORDLIST -o "$wrkpth/PathEnum/$prj_name-gobuster_dns_output-$web.txt" -u example.com
if [ ! -z $wrktmp/WebTargets ]; then
    for web in $(cat $wrktmp/WebTargets); do
        sublist3r -d $web -v -t 25 -o "$wrkpth/SubDomainEnum/$prj_name-$web-sublist3r_output-$current_time.txt"
        amass enum -brute -w $WORDLIST -d $web -ip -o "$wrkpth/SubDomainEnum/$prj_name-$web-amass_output-$current_time.txt"
        gobuster dns -i -t 25 -w $WORDLIST -o "$wrkpth/SubDomainEnum/$prj_name-$web-gobuster_dns_output-$current_time.txt" -d $web
        shuffledns -d $web -w $WORDLIST -o "$wrkpth/SubDomainEnum/$prj_name-$web-shuffledns_output-$current_time.txt" -r /opt/Sherlock/rsc/ressolvers.txt -massdns `which massdns`
        fierce --domain $web --subdomain-file $WORDLIST --traverse 255 | tee -a "$wrkpth/SubDomainEnum/$prj_name-$web-fierce_output-$current_time.json" 
    done
fi
echo

# Checking subdomains against subdomainizer
cat $wrktmp/WebTargets | httprobe | tee -a $wrkpth/SubDomainEnum/SubDomainizer_feed-$current_time
for i in `cat $wrkpth/SubDomainEnum/SubDomainizer_feed-$current_time`; do 
    timeout 1200 python3 /opt/SubDomainizer/SubDomainizer.py -u $i -k -o $wrkpth/SubDomainEnum/$prj_name-subdomainizer_output-$current_time.txt 2> /dev/null
done
echo

# Pulling out all the web targets
for i in `ls $wrkpth/SubDomainEnum/ | grep "$current_time"`; do
    if [ ! -z $wrkpth/SubDomainEnum/$i ]; then
        cat $wrkpth/SubDomainEnum/$i | tr "<BR>" "\n" | tr " " "\n" | tr "," "\n" | tr -d ":" | tr -d "\'" | tr -d "[" | tr -d "]" | sort | uniq >> $wrktmp/TempWeb
        cat $wrkpth/SubDomainEnum/$i | rg --engine -i -o -e "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" >> $wrktmp/TempTargets
        cat $wrkpth/SubDomainEnum/$i | rg --engine -i -e "(\.gov|\.us|\.net|\.com|\.edu|\.org|\.biz|\.io|\.info)" >> $wrktmp/TempWeb
        cat $wrkpth/SubDomainEnum/$i | $IPv6 >> $wrktmp/TempTargetsv6
    fi
done
cat $wrktmp/TempWeb | sort | uniq > $wrktmp/WebTargets
echo

# Using halberd
Banner "Performing scan using Halberd"
cat $wrktmp/WebTargets | parallel -j 10 -k "timeout 300 halberd {} -p 25 -t 90 -v | tee $wrkpth/Halberd/$prj_name-{}-halberd_output-$current_time.txt"
for web in $(ls $wrkpth/Halberd/); do
    if [ ! -z $wrkpth/Halberd/$i ]; then
        cat $wrkpth/Halberd/$i | rg --engine -i -o -e "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" >> $wrktmp/TempTargets
    fi
done
echo

Banner "Some house cleaning"
# Some house cleaning
# PUT IN ADDITIONAL FILTERS FOR IPV4, V6, ETC.
cat $wrktmp/WebTargets | rg --engine -i -e "(\.gov|\.us|\.net|\.com|\.edu|\.org|\.biz|\.io|\.info)" >> $wrktmp/TempWeb
cat $wrktmp/IPtargets | rg --engine -i -o -e "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" >> $wrktmp/TempTargets
cat $wrktmp/IPtargetsv6 | $IPv6 >> $wrktmp/TempTargetsv6
cat $wrktmp/TempWeb | sort | uniq > $wrktmp/WebTargets
cat $wrktmp/TempTargets | sort | uniq > $wrktmp/IPtargets
cat $wrktmp/TempTargetsv6 | sort | uniq > $wrktmp/IPtargetsv6
cat $wrktmp/IPtargets $wrktmp/IPtargetsv6 $wrktmp/WebTargets | tr "<BR>" "\n" | tr " " "\n" | tr "," "\n" | grep -iv found | tr -d ":" | tr -d "\'" | tr -d "[" | tr -d "]" | sort | uniq | tee -a $wrktmp/tempFinal

# Nmap - Pingsweep using ICMP echo, netmask, timestamp
Banner "Nmap Pingsweep - ICMP echo, netmask, timestamp & TCP SYN, and UDP"
nmap -PA"21-23,25,53,80,88,110,111,135,139,443,445,3389,8080" -PE -PM -PP -PO -PS"21-23,25,53,80,88,110,111,135,139,443,445,3389,8080" -PU"42,53,67-68,88,111,123,135,137,138,161,500,3389,5355" -PY"22,80,179,5060" -T5 -R --reason --resolve-all -sn -iL $wrktmp/tempFinal -oA $wrkpth/Nmap/$prj_name-nmap_pingsweep-$current_time
if [ ! -z `$wrktmp/tempFinal | $IPv6 ` ]; then
    nmap -6 -PA"21-23,25,53,80,88,110,111,135,139,443,445,3389,8080" -PS"21-23,25,53,80,88,110,111,135,139,443,445,3389,8080" -PU"42,53,67-68,88,111,123,135,137,138,161,500,3389,5355" -PY"22,80,179,5060" -T5 -R --reason --resolve-all -sn -iL $wrktmp/tempFinal -oA $wrkpth/Nmap/$prj_name-nmap_pingsweepv6-$current_time
fi

# Nmap - Grabing live hosts
Banner "Grabbing livehosts from pingsweep"
if [ -s $wrkpth/Nmap/$prj_name-nmap_pingsweep-$current_time.gnmap ] || [ -r $wrkpth/Nmap/$prj_name-nmap_pingsweep-$current_time.gnmap ]; then
    cat $wrkpth/Nmap/$prj_name-nmap_pingsweep-$current_time.gnmap | grep Up | cut -d ' ' -f 2 >> $wrkpth/Nmap/live-$current_time
    cat $wrkpth/Nmap/live-$current_time | sort | uniq > $wrkpth/Nmap/$prj_name-nmap_pingresponselive-$current_time
fi

if [ -s $wrkpth/Nmap/$prj_name-nmap_pingsweepv6-$current_time.gnmap ] || [ -r $wrkpth/Nmap/$prj_name-nmap_pingsweepv6-$current_time.gnmap ]; then
    cat $wrkpth/Nmap/$prj_name-nmap_pingsweepv6-$current_time.gnmap | grep Up | cut -d ' ' -f 2 >> $wrkpth/Nmap/livev6
    cat $wrkpth/Nmap/livev6 | sort | uniq > $wrkpth/Nmap/$prj_name-nmap_pingresponsev6live-$current_time
fi
echo

# Combining targets
# PUT IN ADDITIONAL FILTERS FOR IPV4, V6, ETC.
Banner "Merging all targets files"
if [ -r $wrkpth/Masscan/live-$current_time ] || [ -r $wrkpth/Nmap/live-$current_time ] || [ -r $wrktmp/TempTargets ] || [ -r $wrktmp/WebTargets ]; then
    # cat $wrkpth/Masscan/live-$current_time | sort | uniq > $wrktmp/TempTargets
    cat $wrkpth/Nmap/live-$current_time | sort | uniq >> $wrktmp/TempTargets
    cat $wrktmp/tempFinal  >> $wrktmp/TempTargets
    cat $wrktmp/WebTargets $wrktmp/tempFinal $wrktmp/TempTargets | tr " " "\n" | tr "," "\n"  | sort | uniq >> $wrktmp/FinalTargets
    cat $wrktmp/TempTargets | rg --engine -i -o -e "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | sort | uniq | tee $wrktmp/IPtargets
    cat $wrktmp/IPtargetsv6 $wrktmp/TempTargetsv6 | $IPv6 >> $wrktmp/FinalTargets
fi
echo 

Banner "Printing final list of targets to be used"
cat $wrktmp/FinalTargets $wrktmp/IPtargets | tr " " "\n" | tr "," "\n" | sort | uniq
echo

# Using masscan to perform a quick port sweep
# Consider switcing to unicornscan
# unicornscan -i eth1 -Ir 160 -E 192.168.1.0/24:1-4000 gateway:a
Banner "Performing portknocking scan using Masscan"
# hostcount=$(wc -l $wrktmp/IPtargets | cut -d " " -f 4)
# nmapTimer=$(expr ((3*65535*$hostcount)/1000)*1.1)
# printf "This portion of the scan will take approx"
# convertAndPrintSeconds $nmapTimer
masscan -iL $wrktmp/IPtargets -p 0-65535 --rate 1000 --open-only --retries 3 -oL $wrkpth/Masscan/$prj_name-masscan_portknock-$current_time.list
if [ -r "$wrkpth/Masscan/$prj_name-masscan_portknock-$current_time.list" ] && [ -s "$wrkpth/Masscan/$prj_name-masscan_portknock-$current_time.list" ]; then
    cat $wrkpth/Masscan/$prj_name-masscan_portknock-$current_time.list | cut -d " " -f 4 | grep -v masscan | sort | uniq >> $wrkpth/$prj_name-livehosts-$current_time
fi
echo 

# Nmap - Full TCP SYN & UDP scan on live-$current_time targets
# time = (max-retries * ports * hosts) / min-rate
# -T4 has a max retry of 6
Banner "Performing portknocking scan using Nmap"
echo "Full TCP SYN & UDP scan on live-$current_time targets"
# hostcount=$(wc -l $wrktmp/FinalTargets | cut -d " " -f 4)
# nmapTimer=$(expr ((6*65535*$hostcount)/300)*1.1)
# printf "This portion of the scan will take approx"
# convertAndPrintSeconds $nmapTimer
nmap -T4 --min-rate 500p -P0 -R --reason --resolve-all -sSU --open -p- -iL $wrktmp/FinalTargets -oA $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time
if [ ! ! -z `$wrktmp/FinalTargets | $IPv6 ` ]; then
    nmap -T4 --min-rate 500p -6 -P0 -R --reason --resolve-all -sSU --open -p- -iL $wrktmp/FinalTargets -oA $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time
fi

# Enumerating the services discovered by nmap
if [ -r $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.xml ] || [ -r $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap ]; then
    for i in `cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep Ports | cut -d "/" -f 5 | tr "|" "\n" | sort | uniq`; do # smtp domain telnet microsoft-ds netbios-ssn http ssh ssl ms-wbt-server imap; do
        cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap | grep $i | grep open | cut -d ' ' -f 2 | grep -iv nmap | sort | uniq | tee -a $wrkpth/Nmap/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time
        cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap | grep -E "(\.gov|\.us|\.net|\.com|\.edu|\.org|\.biz|\.io|\.info|\.tv)" | cut -d " " -f 3 | cut -d "(" -f 2 | cut -d ")" -f 1 | grep -iv nmap | sort | uniq | tee -a $wrkpth/Nmap/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time
        cat $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $i | grep open | cut -d ' ' -f 2 | grep -iv nmap | $IPv6 | tee -a $wrkpth/Nmap/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time-v6
        cat $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep -E "(\.gov|\.us|\.net|\.com|\.edu|\.org|\.biz|\.io|\.info|\.tv)" | cut -d " " -f 3 | cut -d "(" -f 2 | cut -d ")" -f 1 | grep -iv nmap | sort | uniq | tee -a $wrkpth/Nmap/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time-v6
    done
else
    echo "Something want wrong, ethier the nmap output files do not exist or it is were empty
    I recommend chacking the $wrkpth/Nmap/
    Then check your network connection & re-run this script"
    gift_wrap
    exit
fi
echo

# Using testssl & sslcan
Banner "Performing scan using testssl"
python3 /opt/brutespray/brutespray.py --file $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap -U /usr/share/seclists/Usernames/cirt-default-usernames.txt -P /usr/share/seclists/Passwords/cirt-default-passwords.txt --threads 10 --hosts 10 -c --output $wrkpth/l00tz
echo

# Checking all the services discovery by nmap
for i in `cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep Ports | cut -d "/" -f 5 | tr "|" "\n" | sort | uniq`; do
    Banner "Performing targeted scan of $i"
    PORTNUM=($(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep Ports | cut -d ":" -f 3 | tr "," "\n" | grep -iv nmap | grep -i $i | cut -d "/" -f 1 | tr -d " " | sort | uniq))
    # hostcount=$(wc -l $wrktmp/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time | cut -d " " -f 4)
    # nmapTimer=$(expr ((6*${#PORTNUM[@]}*$hostcount)/300)*2.5)
    # printf "This portion of the scan will take approx"
    # convertAndPrintSeconds $nmapTimer
    nmap -T4 --min-rate 300p -A -P0 -R --reason --resolve-all -sSUV --open -p "$(echo ${PORTNUM[*]} | tr  " " ",")" --script="$(ls /usr/share/nmap/scripts/ | grep $i | grep -iv brute | tr "\n" ",")$NMAP_SCRIPTS" --script-args "$NMAP_SCRIPTARG" -iL $wrkpth/Nmap/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time -oA $wrkpth/Nmap/$prj_name-nmap_$i
    if [ ! -z `echo $i | tr '[:lower:]' '[:upper:]' | $IPv6` ]; then
        nmap -6 -T4 --min-rate 300p -A -P0 -R --reason --resolve-all -sSUV --open -p "$(echo ${PORTNUM[*]} | sed 's/ /,/g')" --script="$(ls /usr/share/nmap/scripts/ | grep $i | grep -iv brute | tr "\n" ",")$NMAP_SCRIPTS" --script-args "$NMAP_SCRIPTARG" -iL $wrkpth/Nmap/`echo $i | tr '[:lower:]' '[:upper:]'`-$current_time-v6 -oA $wrkpth/Nmap/$prj_name-nmapv6_$i
   fi
done
unset PORTNUM
echo

# Using batea
Banner "Ranking nmap output using batea"
for i in `ls $wrkpth/Nmap/ | grep -i xml | grep "$current_time"`; do
    batea -v $wrkpth/Nmap/$i | tee -a  $wrkpth/Batea/$prj_name-batea_output-$current_time.json 2> /dev/null
done
echo

# Using DNS Recon
# Will revise this later to account for other ports one might use for dns
Banner "Performing scan using DNS Scan"
if [ -s $wrkpth/Nmap/DOMAIN-$current_time ]; then
    for IP in $(cat $wrkpth/Nmap/DOMAIN-$current_time); do
        echo Scanning $IP
        echo "--------------------------------------------------"
        dnsrecon -d $IP -a | tee -a $wrkpth/DNS_Recon/$prj_name-$IP-$web-DNSRecon_output-$current_time.txt
        dnsrecon -d $IP  -t zonewalk | tee -a $wrkpth/DNS_Recon/$prj_name-$IP-$web-DNSRecon_output-$current_time.txt
        echo "--------------------------------------------------"
    done
fi
echo

# Using SSH Audit
Banner "Performing scan using SSH Audit"
if [ -s $wrkpth/Nmap/SSH-$current_time ]; then
    SSHPort=($(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep Ports | cut -d ":" -f 3 | tr "," "\n" | grep -iv nmap | grep -i ssh | cut -d "/" -f 1 | tr -d " " | sort | uniq))
    for IP in $(cat $wrkpth/Nmap/SSH-$current_time); do
        STAT1=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $IP | grep "Status: Up" -m 1 -o | cut -c 9-10) # Check to make sure the host is in fact up
        STAT2=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $IP | grep "$PORTNUM/open/tcp//ssh" -m 1 -o | grep "ssh" -o) # Check to see if the port is open & is a web service
        STAT3=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $IP | grep "$PORTNUM/filtered/tcp//ssh" -m 1 -o | grep "ssh" -o) # Check to see if the port is filtered & is a web service
        if [ "$STAT1" == "Up" ] && [ "$STAT2" == "ssh" ] || [ "$STAT3" == "ssh" ]; then
            for PORTNUM in ${SSHPort[*]}; do
                echo Scanning $IP
                echo "--------------------------------------------------"
                ssh-audit -n $IP -p  $PORTNUM | aha -t "SSH Audit" > $wrkpth/SSH/$prj_name-$IP:$PORTNUM-ssh-audit_output-$current_time.html
                echo "--------------------------------------------------"
                ssh_scan -t $IP -p $PORTNUM -o $wrkpth/SSH/$prj_name-$IP:$PORTNUM-ssh-scan_output-$current_time.json
                echo "--------------------------------------------------"
                msfconsole -q -x "use auxiliary/scanner/ssh/ssh_enumusers; set RHOSTS file:$wrkpth/Nmap/SSH; set RPORT $PORTNUM; set USER_FILE /usr/share/seclists/Usernames/cirt-default-usernames.txt; set THREADS 25; exploit; exit -y" 2> /dev/null | tee -a $wrkpth/SSH/$prj_name-ssh-msf-$web.txt
            done
        fi
    done
fi
echo

# Using testssl & sslcan
# switch back to for loop, testssl doesnt properly parse gnmap
Banner "Performing scan using testssl"
cd $wrkpth/SSL/
testssl --append --assume-http --csv --full --html --json-pretty --log --parallel --sneaky --file $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap | tee -a $wrkpth/SSL/$prj_name-TestSSL_output-$current_time.txt
if [ ! -z `$wrktmp/FinalTargets | $IPv6` ]; then
    testssl -6 --append --assume-http --csv --full --html --json-pretty --log --parallel --sneaky --file $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | tee -a $wrkpth/SSL/$prj_name-TestSSL_outputv6.txt
fi
find $wrkpth/SSL/ -type f -size -1k -delete
cd $pth
echo

# Combining ports
# echo "--------------------------------------------------"
# echo "Combining ports
# echo "--------------------------------------------------"
# Merging HTTP and SSL ports
HTTPPort=($(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep Ports | cut -d ":" -f 3 | tr "," "\n" | grep -iv nmap | grep -i http | cut -d "/" -f 1 | tr -d " " | sort | uniq))
SSLPort=($(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep Ports | cut -d ":" -f 3 | tr "," "\n" | grep -iv nmap | grep -i ssl | cut -d "/" -f 1 | tr -d " " | sort | uniq))
if [ -z ${#HTTPPort[@]} ] && [ -z ${#SSLPort[@]} ]; then
    echo "There are no open web or ssl ports, exiting now"
    gift_wrap
    exit
fi
NEW=$(echo "${HTTPPort[@]}" "${SSLPort[@]}" | awk '/^[0-9]/' | sort | uniq) # Will need testing
# Consider using the below script to parse for ports (https://github.com/superkojiman/scanreport)
# ./scanreport.sh -f XPC-2020Q1-nmap_portknock.gnmap -s http | grep -v Host | cut -d$'\t' -f 1 | sort | uniq

# Using Eyewitness to take screenshots
Banner "Performing scan using EyeWitness & aquafone"
if [ ! -z $wrkpth/Nmap/HTTP-$current_time ] || [ ! -z $wrkpth/Nmap/HTTPS-$current_time]; then 
    eyewitness -x $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.xml --resolve --web --prepend-https --threads 25 --no-prompt --resolve -d $wrkpth/EyeWitness/
    if [ ! -z `$wrktmp/FinalTargets | $IPv6 ` ]; then
        eyewitness -x $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.xml --resolve --web --prepend-https --threads 25 --no-prompt --resolve -d $wrkpth/EyeWitnessv6/
    fi
    # Using aquafone
    cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.xml | aquatone -nmap -out $wrkpth/Aquatone/ -ports xlarge -threads 10
    if [ ! -z `$wrktmp/FinalTargets | $IPv6 ` ]; then
        cat $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.xml | aquatone -nmap -out $wrkpth/Aquatone/ -ports xlarge -threads 10
    fi
fi
echo 

# Using theharvester & metagoofil
# look into the conditional
Banner "Performing scan using Theharvester and Metagoofil"
for web in $(cat $wrktmp/FinalTargets); do
    for PORTNUM in ${NEW[*]}; do
        STAT1=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "Status: Up" -m 1 -o | cut -c 9-10) # Check to make sure the host is in fact up
        STAT2=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is open & is a web service
        STAT3=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is filtered & is a web service
        STAT4=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//ssl" | grep "ssl" -o) # Check to see if the port is open & ssl enabled
        STAT5=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//ssl" | grep "ssl" -o) # Check to see if the port is filtered & ssl enabled
        if [ "$STAT1" == "Up" ] && [ "$STAT2" == "http" ] || [ "$STAT3" == "http" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
            timeout 900 theHarvester -d http://$web:$PORTNUM -l 500 -b all | tee $wrkpth/Harvester/$prj_name-$web-$PORTNUM-harvester_http_output-$current_time.txt
            timeout 900 metagoofil -d http://$web:$PORTNUM -l 500 -o $wrkpth/Metagoofil/Evidence -f $wrkpth/Metagoofil/$prj_name-$web-$PORTNUM-metagoofil_http_output-$current_time.html -t pdf,doc,xls,ppt,odp,od5,docx,xlsx,pptx
         fi

        if [ "$STAT1" == "Up" ] && [ "$STAT4" == "ssl" ] && [ "$STAT5" == "ssl" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
            timeout 900 theHarvester -d https://$web:$PORTNUM -l 500 -b all | tee $wrkpth/Harvester/$prj_name-$web-$PORTNUM-harvester_https_output-$current_time.txt
            timeout 900 metagoofil -d https://$web:$PORTNUM -l 500 -o $wrkpth/Metagoofil/Evidence -f $wrkpth/Metagoofil/$prj_name-$web-$PORTNUM-metagoofil_https_output-$current_time.html -t pdf,doc,xls,ppt,odp,od5,docx,xlsx,pptx
            echo "--------------------------------------------------"
        fi
    done
done
if [ -d $wrkpth/Harvester/Evidence/ ]; then
    for files in $(ls $wrkpth/Harvester/Evidence/ | grep pdf); do
        pdfinfo $files.pdf | grep Author | cut -d " " -f 10 | tee -a $wrkpth/Harvester/tempusr
    done
    cat $wrkpth/Harvester/tempusr | sort | uniq > $wrkpth/Harvester/Usernames
    rm $wrkpth/Harvester/tempusr
fi
echo

# Using Wappalyzer
Banner "Performing scan using Wappalyzer"
for web in $(cat $wrktmp/FinalTargets); do
    for PORTNUM in ${NEW[*]}; do
        STAT1=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "Status: Up" -m 1 -o | cut -c 9-10) # Check to make sure the host is in fact up
        STAT2=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is open & is a web service
        STAT3=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is filtered & is a web service
        STAT4=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//ssl" | grep "ssl" -o) # Check to see if the port is open & ssl enabled
        STAT5=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//ssl" | grep "ssl" -o) # Check to see if the port is filtered & ssl enabled
        if [ "$STAT1" == "Up" ] && [ "$STAT2" == "http" ] || [ "$STAT3" == "http" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
            if hash wappalyzer 2> /dev/null; then
                wappalyzer $web:$PORTNUM | python -m json.tool | tee -a $wrkpth/Wappalyzer/$prj_name-$web-wappalyzer_output-$current_time.json
            elif hash docker 2> /dev/null; then
                docker run --rm wappalyzer/cli $web:$PORTNUM | python -m json.tool | tee -a $wrkpth/Wappalyzer/$prj_name-$web-wappalyzer_output-$current_time.json
            fi
        elif [ "$STAT1" == "Up" ] && [ "$STAT4" == "ssl" ] && [ "$STAT5" == "ssl" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
             if hash wappalyzer 2> /dev/null; then
                wappalyzer $web:$PORTNUM | python -m json.tool | tee -a $wrkpth/Wappalyzer/$prj_name-$web-wappalyzer_output-$current_time.json
            elif hash docker 2> /dev/null; then
                docker run --rm wappalyzer/cli $web:$PORTNUM | python -m json.tool | tee -a $wrkpth/Wappalyzer/$prj_name-$web-wappalyzer_output-$current_time.json
            fi
        fi
    done
done
find $wrkpth/Wappalyzer/ -type f -size -1k -delete
echo

# Using XSStrike
Banner "Performing scan using XSStrike"
for web in $(cat $wrktmp/FinalTargets); do
    for PORTNUM in ${NEW[*]}; do
        STAT1=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "Status: Up" -m 1 -o | cut -c 9-10) # Check to make sure the host is in fact up
        STAT2=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is open & is a web service
        STAT3=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is filtered & is a web service
        STAT4=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//ssl" | grep "ssl" -o) # Check to see if the port is open & ssl enabled
        STAT5=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//ssl" | grep "ssl" -o) # Check to see if the port is filtered & ssl enabled
        if [ "$STAT1" == "Up" ] && [ "$STAT2" == "http" ] || [ "$STAT3" == "http" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
            python3 /opt/XSStrike/xsstrike.py -u https://$web:$PORTNUM --crawl -t 10 -l 10 | tee -a $wrkpth/XSStrike/$prj_name-$web-$PORTNUM-xsstrike_output-$current_time.txt
            echo "--------------------------------------------------"
        fi

        if [ "$STAT1" == "Up" ] && [ "$STAT4" == "ssl" ] && [ "$STAT5" == "ssl" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
            python3 /opt/XSStrike/xsstrike.py -u http://$web:$PORTNUM --crawl -t 10 -l 10 | tee -a $wrkpth/XSStrike/$prj_name-$web-$PORTNUM-xsstrike_output-$current_time.txt
            echo "--------------------------------------------------"
        fi
    done
done
find $wrkpth/XSStrike/ -type f -size -1k -delete
echo

# Using nikto
Banner "Performing scan using Nikto"
nikto -C all -host $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap -output $wrkpth/Nikto/$prj_name-nikto_output.csv -Display 1,2,3,4,E,P -maxtime 90m | tee $wrkpth/Nikto/$prj_name-nikto_output-$current_time.txt
if [ ! -z `$wrktmp/FinalTargets | $IPv6 ` ]; then
    nikto -C all -host $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap -output $wrkpth/Nikto/$prj_name-nikto_output.csv -Display 1,2,3,4,E,P -maxtime 90m | tee $wrkpth/Nikto/$prj_name-nikto_output-$current_time.txt
fi
echo

# Using gospider
Banner "Performing path traversal enumeration"
for web in $(cat $wrktmp/FinalTargets); do
    for PORTNUM in ${NEW[*]}; do
        STAT1=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "Status: Up" -m 1 -o | cut -c 9-10) # Check to make sure the host is in fact up
        STAT2=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is open & is a web service
        STAT3=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//http" -m 1 -o | grep "http" -o) # Check to see if the port is filtered & is a web service
        STAT4=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open/tcp//ssl" | grep "ssl" -o) # Check to see if the port is open & ssl enabled
        STAT5=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered/tcp//ssl" | grep "ssl" -o) # Check to see if the port is filtered & ssl enabled
        if [ "$STAT1" == "Up" ] && [ "$STAT2" == "http" ] || [ "$STAT3" == "http" ]; then
            echo Scanning $web:$PORTNUM
            gospider -s "http://$web:$PORTNUM" -o $wrkpth/PathEnum/GoSpider -c 10 -d 5 -t 10 -a | tee -a $wrkpth/PathEnum/$prj_name-$web-$PORTNUM-gospider_output.log
            hakrawler --url $web:$PORTNUM -js -linkfinder -robots -subs -urls -usewayback -insecure -outdir $wrkpth/PathEnum/Hakcrawler | tee -a $wrkpth/PathEnum/$prj_name-$web-$PORTNUM-hakrawler_output.log
        fi

        if [ "$STAT1" == "Up" ] && [ "$STAT4" == "ssl" ] && [ "$STAT5" == "ssl" ]; then
            echo Scanning $web:$PORTNUM
            gospider -s "https://$web:$PORTNUM" -o $wrkpth/PathEnum/GoSpider -c 10 -d 5 -t 10 -a | tee -a $wrkpth/PathEnum/$prj_name-$web-$PORTNUM-gospider_output.log
            hakrawler --url $web:$PORTNUM -js -linkfinder -robots -subs -urls -usewayback -insecure -outdir $wrkpth/PathEnum/Hakcrawler | tee -a $wrkpth/PathEnum/$prj_name-$web-$PORTNUM-hakrawler_output.log
        fi
    done
done
echo

# Using Wapiti, arjun and ffuf
Banner "Performing scan using Wapiti, arjun, and ffuf"
for web in $(cat $wrktmp/FinalTargets); do
    for PORTNUM in ${NEW[*]}; do
        STAT1=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "Status: Up" -m 1 -o | cut -c 9-10) # Check to make sure the host is in fact up
        STAT2=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/open" -m 1 -o | grep "open" -o) # Check to see if the port is open & is a web service
        STAT3=$(cat $wrkpth/Nmap/$prj_name-nmap_portknock-$current_time.gnmap $wrkpth/Nmap/$prj_name-nmap_portknockv6-$current_time.gnmap | grep $web | grep "$PORTNUM/filtered" -m 1 -o | grep "filtered" -o) # Check to see if the port is filtered & is a web service
        if [ "$STAT1" == "Up" ] && [ "$STAT2" == "open" ] || [ "$STAT3" == "filtered" ]; then
            echo Scanning $web:$PORTNUM
            echo "--------------------------------------------------"
            wapiti -u "http://$web:$PORTNUM/" -o $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-wapiti_http_result-$current_time -f html -m "all" -v 1 2> /dev/null | tee -a $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-wapiti_result.log
            wapiti -u "https://$web:$PORTNUM/" -o $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-wapiti_https_result-$current_time -f html -m "all" -v 1 2> /dev/null | tee -a $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-wapiti_result.log
            pythoon3 /opt/Arjun/arjun.py -u "https://$web:$PORTNUM/" --get --post -t 10 -f /opt/Arjun/db/params.txt -o $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-arjun_https_output-$current_time.txt 2> /dev/null
            pythoon3 /opt/Arjun/arjun.py -u "http://$web:$PORTNUM/" --get --post -t 10 -f /opt/Arjun/db/params.txt -o $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-arjun_http_output-$current_time.txt 2> /dev/null
            ffuf -r -recursion -recursion-depth 5 -ac -maxtime 600 -w  $WORDLIST -mc 200,401,403 -of all -o $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-ffuf_https_output -c -u "https://$web:$PORTNUM/FUZZ"
            ffuf -r -recursion -recursion-depth 5 -ac -maxtime 600 -w  $WORDLIST -mc 200,401,403 -of all -o $wrkpth/WebVulnScan/$prj_name-$web-$PORTNUM-ffuf_http_output -c -u "http://$web:$PORTNUM/FUZZ"
            echo "--------------------------------------------------"
        fi
    done
done
echo

# WRapping up assessment
gift_wrap
} 2> /dev/null | tee -a $pth/$prj_name-sherlock_output-$current_time.txt