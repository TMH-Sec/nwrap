#!/usr/bin/sudo bash
[[ $(which nmap 2>/dev/null) ]] || { echo -e "\n\e[1;31mPlease install nmap and rerun $0.";exit 1; }
[[ $(which xmlstarlet 2>/dev/null) ]] || { echo -e "\n\e[1;31mPlease install xmlstarlet and rerun $0.";exit 1; }

usage() { echo "$0 usage: Help Goes Here!" && grep ".)\ #" $0; exit 0; }
[ $# -eq 0 ] && usage

while getopts "H:MANVh" opt # if option expects parameter, it is followed by :
do
  case "$opt" in
  H) hosts="$OPTARG" ;;
  M) more_ports="--top-ports 10000" ;;
  A) all_ports="-p-" ;;
  N) no_ping="-Pn" ;;
  V) service="true" ;;
  h | *) usage ;;
  esac
done
shift $((OPTIND -1))

echo -e "\e[1;33mLooking for open ports in $hosts"
if [ "$more_ports" -a "$no_ping" ]
then
  command="nmap -sS $no_ping $more_ports -oG - $hosts" # splits into lines
  command_sv="nmap -sSV $no_ping $more_ports $hosts -oX"
elif [ "$all_ports" -a "$no_ping" ]
then
  command="nmap -sS $no_ping $all_ports -oG - $hosts"
  command_sv="nmap -sSV $no_ping $all_ports $hosts -oX"
elif [ "$more_ports" ]
then
  command="nmap -sS $more_ports -oG - $hosts"
  command_sv="nmap -sSV $more_ports $hosts -oX"
elif [ "$all_ports" ]
then
  command="nmap -sS $all_ports -oG - $hosts"
  command_sv="nmap -sSV $all_ports $hosts -oX"
else
  command="nmap -sS -oG - $hosts"
  command_sv="nmap -sSV $hosts -oX"
fi

echo -e "\e[0;36mRunning: $command"
command_output="$($command 2>/dev/null | grep open)"
numhosts="$(echo $command_output | wc -l)" # now you can count lines for num hosts
OLDIFS=$' \t\n' # save the value of IFS, normally <space><tab><newline>

if [ $numhosts -gt 0 ]
then
  IFS=$'\n'
  for line in $command_output
  do
    open_ports=""
    index="$(echo $line | grep -o open | wc -l)"
    host="$(echo $line | grep -o '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*')"
    ports_group="$(echo $line | grep -o '[0-9]*\/open')"
    for port in $ports_group
    do
      open_ports+="${port%/open}" # %/open removes /open
        if [ $index -gt 1 ]
        then
          index="$((--index))" # decrement the index
          open_ports+=","
        fi
    done
    echo -e "\e[0;32mHost IP: $host Ports: $open_ports"
  done
else
  echo "You are not going to find open ports that way!"
  usage
fi
IFS=$OLDIFS
if [ "$service" == "true" ]
then
  echo -e "\e[0;35mEnumerating Services"
  echo -e "\e[0;33mRunning: $command_sv"
  xmlvar="$($command_sv xmlshizzle.xml)"
  open_ports_ipaddr="$(cat xmlshizzle.xml | xmlstarlet sel -t -m '//port[state[@state="open"]]/../../address[@addrtype="ipv4"]' -v @addr -o ' ')"
  for ip in $open_ports_ipaddr
  do
    echo -e "\e[0;32m$ip"
    query_string0="sel -t -m //host[address[@addr="
    query_string1="$ip"
    query_string2="]]/ports/port"
    query_string3=" -v @portid -o __ -v service/@name -o __ -v service/@product -o __ -v service/@version -n xmlshizzle.xml"
    query=$(xmlstarlet $query_string0'"'$query_string1'"'$query_string2$query_string3)
    echo -e "\e[1;36m$query"
  done
else
  exit 0
fi
