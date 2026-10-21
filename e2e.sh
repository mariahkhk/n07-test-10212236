set -u
api(){ curl -s -X POST -H 'Content-Type: application/json-rpc' ${TOK:+-H "Authorization: Bearer $TOK"} -d "$1" localhost:8080/api_jsonrpc.php; }
mkdir -p ~/zabbix && cp zcompose.yaml ~/zabbix/compose.yaml && cd ~/zabbix
echo "ZBX_DB_PASSWORD=$(openssl rand -hex 12)" > .env
echo "== A2 port kinni"; docker run -d --name ankur -p 8080:80 nginx:1.27 >/dev/null
docker compose up -d 2>&1 | grep -i "allocated"; docker compose ps -a --format '{{.Service}} {{.State}}'
docker rm -f ankur >/dev/null; docker compose up -d 2>/dev/null; for i in $(seq 60); do curl -fs -o /dev/null localhost:8080/ && break; sleep 2; done
docker compose ps > $GITHUB_WORKSPACE/repo/logid/a2-compose-ps.txt; cat $GITHUB_WORKSPACE/repo/logid/a2-compose-ps.txt
cp compose.yaml $GITHUB_WORKSPACE/repo/konf/
TOK=$(api '{"jsonrpc":"2.0","method":"user.login","params":{"username":"Admin","password":"zabbix"},"id":1}' | jq -r .result)
GW=$(docker network inspect zabbix_default -f '{{(index .IPAM.Config 0).Gateway}}')
TPL=$(api '{"jsonrpc":"2.0","method":"template.get","params":{"filter":{"host":["ICMP Ping"]}},"id":1}' | jq -r '.result[0].templateid')
mk(){ api "{\"jsonrpc\":\"2.0\",\"method\":\"host.create\",\"params\":{\"host\":\"$1\",\"interfaces\":[{\"type\":1,\"main\":1,\"useip\":1,\"ip\":\"$2\",\"dns\":\"\",\"port\":\"10050\"}],\"groups\":[{\"groupid\":\"2\"}],\"templates\":[{\"templateid\":\"$TPL\"}]},\"id\":1}" | jq -r '.result.hostids[0]'; }
mk proxmox2 $GW >/dev/null; H3=$(mk proxmox3 10.255.255.1)
echo "== A4 fping"; docker compose exec -T zabbix-server fping $GW; docker compose exec -T zabbix-server fping -t 500 10.255.255.1; echo "fping rc=$?"
for i in $(seq 40); do p=$(api '{"jsonrpc":"2.0","method":"problem.get","params":{"output":["name"]},"id":1}' | jq -r '.result[].name'); [ -n "$p" ] && break; sleep 10; done; echo "== A5 probleem: $p ($((i*10))s)"
IID=$(api "{\"jsonrpc\":\"2.0\",\"method\":\"hostinterface.get\",\"params\":{\"hostids\":\"$H3\"},\"id\":1}" | jq -r '.result[0].interfaceid')
api "{\"jsonrpc\":\"2.0\",\"method\":\"hostinterface.update\",\"params\":{\"interfaceid\":\"$IID\",\"ip\":\"$GW\"},\"id\":1}" >/dev/null
for i in $(seq 40); do n=$(api '{"jsonrpc":"2.0","method":"problem.get","params":{"output":["name"]},"id":1}' | jq '.result|length'); [ "$n" = 0 ] && break; sleep 10; done; echo "== lahenes $((i*10))s"
docker compose exec -T postgres psql -U zabbix -c "SELECT host FROM hosts WHERE host LIKE 'proxmox%' ORDER BY host;" -c "SELECT name, to_timestamp(clock) AS algas, to_timestamp(r_clock) AS lahenes FROM problem ORDER BY clock;" > $GITHUB_WORKSPACE/repo/logid/a5-andmebaas.txt
cat $GITHUB_WORKSPACE/repo/logid/a5-andmebaas.txt
docker compose stop zabbix-server; sleep 5; curl -s localhost:8080/ | grep -o "Zabbix server is not running[^<]*" | head -1; docker compose down
sed -i 's/_vastus_/vastus olemas/' $GITHUB_WORKSPACE/repo/README.md
