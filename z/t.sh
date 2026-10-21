set -x
cd z
echo "ZBX_DB_PASSWORD=salajane123" > .env
# 1. port kinni (N6 nginx 8080)
docker run -d --name n6 -p 8080:80 nginx:1.27
docker compose up -d 2>&1 | tail -5
docker compose ps -a
docker rm -f n6; docker compose up -d
T0=$(date +%s)
for i in $(seq 90); do c=$(curl -s -o /tmp/p.html -w '%{http_code}' localhost:8080/); [ "$c" = 200 ] && grep -q "Sign in\|Username" /tmp/p.html && break; sleep 2; done
echo "WEB valmis $(( $(date +%s)-T0 ))s kood=$c"; grep -o "<title>[^<]*" /tmp/p.html
docker compose logs zabbix-server | tail -15
docker stats --no-stream --format '{{.Name}} {{.MemUsage}}'
api(){ curl -s -X POST -H 'Content-Type: application/json-rpc' ${TOK:+-H "Authorization: Bearer $TOK"} -d "$1" localhost:8080/api_jsonrpc.php; }
api '{"jsonrpc":"2.0","method":"apiinfo.version","params":{},"id":1}'; echo
TOK=$(api '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' | jq -r .result); echo TOK=${TOK:0:6}
GW=$(docker network inspect z_default -f '{{(index .IPAM.Config 0).Gateway}}'); echo GW=$GW
TPL=$(api '{"jsonrpc":"2.0","method":"template.get","params":{"filter":{"host":["ICMP Ping"]}},"id":1}' | jq -r '.result[0].templateid'); echo TPL=$TPL
GRP=$(api '{"jsonrpc":"2.0","method":"hostgroup.get","params":{"filter":{"name":["Linux servers"]}},"id":1}' | jq -r '.result[0].groupid'); echo GRP=$GRP
mk(){ api "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$1\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$2\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"$GRP\"}],\"templates\":[{\"templateid\":\"$TPL\"}]},\"id\":1}"; echo; }
mk proxmox2 $GW; mk proxmox3 10.255.255.1
T1=$(date +%s)
for i in $(seq 80); do
  v=$(api '{"jsonrpc":"2.0","method":"item.get","params":{"host":"proxmox2","search":{"key_":"icmpping"},"output":["key_","lastvalue","lastclock"]},"id":1}' | jq -c '[.result[]|{k:.key_,v:.lastvalue,c:.lastclock}]')
  p=$(api '{"jsonrpc":"2.0","method":"problem.get","params":{"output":["name","clock"],"recent":true},"id":1}' | jq -c '[.result[]|.name]')
  echo "$(( $(date +%s)-T1 ))s ok=$v prob=$p"; echo "$p" | grep -q "proxmox3\|ICMP" && break; sleep 10; done
api '{"jsonrpc":"2.0","method":"host.get","params":{"output":["host"],"selectInterfaces":["available"]},"id":1}' | jq -c .result
api '{"jsonrpc":"2.0","method":"item.get","params":{"host":"Zabbix server","output":["key_","lastvalue"],"limit":8,"filter":{"state":0}},"id":1}' | jq -c '[.result[]|select(.lastvalue!="0" and .lastvalue!="")|.key_]'
api '{"jsonrpc":"2.0","method":"problem.get","params":{"output":["name"]},"id":1}' | jq -c '[.result[]|.name]'
