#!/bin/bash

function select_options (){
echo -e "${GR}*****************         Menu         *****************${NC}" && echo -e ""
options=("Ceph deploy" "Ceph destroy" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Ceph deploy")
			deploy_initial_node
			install_base_packages
			deploy_initial_monitor
			create_osd_dir
			prepare_osd
			activate_osd
			gather_keys
			check_health
			deploy_osd_monitors
			deploy_mds_and_rgw
			show_cluster_map
            ;;
		"Ceph destroy")
			break
			;;
        "Quit")
            break
            ;;
        *) echo invalid option;;
    esac
done
}
function deploy_initial_node () {
echo -e ""
echo -e "${GR}Insert initial node IP or hostname ${NC}\n"
read node && echo -e ""
echo -e "${GR}Insert ceph subnet with mask ${NC}\n"
read subnet && echo -e ""
echo -e "${GR}Insert ceph replica count ${NC}\n"
read replicas && echo -e ""

ceph-deploy new $node
echo -e "${GR}Modifyinng ceph cluster config file... ${NC}\n" && echo "public network = $subnet" >> ceph.conf && echo "osd pool default pg num = 100" >> ceph.conf && echo "osd pool default pgp num = 100" >> ceph.conf
cat ceph.conf

}
function install_base_packages () {
unset xargs
echo -e "${GR}Insert number of nodes to patch for osd function${NC}\n"
read args && echo -e ""

if [[ $args =~ ^-?[0-9]+$ ]]; then
	for (( i=0;i<$args;i++))
	do 
		echo -e "${GR}Node $i IP or hostname${NC}\n"
		read xargs[i]
		echo -e ""
	done
else
	echo -e "Insert an integer"
	install_base_packages
fi

ceph-deploy install $node ${xargs[*]}
echo -e ""
}
function deploy_initial_monitor () {
echo -e "${GR}Deploying intial monitor function...${NC}"
echo -e "${GR}Monitor will be setup on initial node...${NC}\n"

ceph-deploy mon create-initial $node

echo -e "${GR}Initial monitor created${NC}"
}
function create_osd_dir () {
echo -e "${GR}Connecting to ceph nodes...${NC}"
echo -e "${GR}Deploying osd directories...${NC}"
echo -e "${GR}Changing ownership privileges...${NC}\n"

	for i in "${xargs[@]}"
		do
			ssh -o StrictHostKeyChecking=no -t root@$i "mkdir -p /var/local/osd0 && mkdir -p /var/local/osd1 && chown ceph:ceph /var/local/osd0 && chown ceph:ceph /var/local/osd1 && chown ceph:ceph /dev/sda1 && exit"
		done
echo -e "${GR}Finshed creating osd directories${NC}\n"
}
function prepare_osd () {
echo -e "${GR}Connecting to ceph nodes...${NC}"
echo -e "${GR}Preparing osd directories...${NC}\n"

	for i in "${xargs[@]}"
		do
			ceph-deploy osd prepare $xargs[i]:/var/local/osd0 $xargs[i]:/var/local/osd1
		done

echo -e "${GR}Finished preparing osd directories...${NC}\n"
}
function activate_osd () {
echo -e "${GR}Connecting to ceph nodes...${NC}"
echo -e "${GR}Activating osd directories...${NC}\n"

	for i in "${xargs[@]}"
		do
			ceph-deploy osd activate $xargs[i]:/var/local/osd0 $xargs[i]:/var/local/osd1
		done

echo -e "${GR}Finished activating osd directories...${NC}\n"
}
function gather_keys () {
echo -e "${GR}Connecting to ceph nodes...${NC}"
echo -e "${GR}Gathering ceph access keys...${NC}\n"

ceph-deploy admin $node ${xargs[*]}
sudo chmod +r /etc/ceph/ceph.client.admin.keyring

echo -e "${GR}Finished collecting keys...${NC}\n"
}
function check_health () {
echo -e "${GR}Checking cluster health...${NC}"
health=$(ceph health)

if [ "$health" == "HEALTH_OK" ]; then
	echo -e "${GR}Cluster healthy...${NC}\n"

else 
	check_health
fi	
}
function deploy_osd_monitors () {
echo -e "${GR}Connecting to ceph nodes...${NC}"
echo -e "${GR}Activating monitor functions...${NC}\n"

	for i in "${xargs[@]}"
		do
			ceph-deploy mon add  $xargs[i]
		done

echo -e "${GR}Finished activating monitor functions...${NC}\n"
}
function deploy_mds_and_rgw () {
echo -e "${GR}Creating Metadata server on initial node...${NC}\n"
ceph-deploy mds create $node
echo -e "${GR}Creating Rados Gateway in initial node...${NC}\n"
ceph-deploy rgw create $node
echo -e ""
}
function show_cluster_map (){
cluster_map=$(ceph osd tree)
echo -e "${GR}Deployed cluster map...${NC}"
echo -e "$cluster map"
echo -e "${GR}***********************${NC}"
echo -e "${GR}*******  Finish *******${NC}"
echo -e "${GR}***********************${NC}"
}

#main
GR='\033[0;32m'
NC='\033[0m' 

echo -e "${GR}***************** Ceph deployment tool *****************${NC}"
select_options

