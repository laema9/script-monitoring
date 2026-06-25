#!/bin/bash

echo "[+] Lancement du script de monitoring"
echo "---------------------------------------------------------------------"

hostname 
date
whoami

date=$(date +%Y-%m-%d-%T)
hostname_var=$(hostname)
utilisateur=$(whoami)

echo "---------------------------------------------------------------------"
echo "[+] Vérification des services fake-api, log-generator, noisy-workers"

if systemctl is-active --quiet fake-api
then
    fakeapi_etat='Ok'
else
    fakeapi_etat='Nok'
fi

if systemctl is-active --quiet log-generator
then
    loggen_etat='Ok'
else
    loggen_etat='Nok'
fi

if systemctl is-active --quiet noisy-workers
then
    noisyworker_etat='Ok'
else
    noisyworker_etat='Nok'
fi

mkdir -p "/opt/monitoring-lab/plc/reports/run-${date}"

# état des services

touch "/opt/monitoring-lab/plc/reports/run-${date}/services.txt"
echo -e "RUN : ${date}
MACHINE : ${hostname_var}
Utilisateur courant : ${utilisateur}
FAKE_API est ${fakeapi_etat}
LOG-GENERATOR est ${loggen_etat}
NOISY-WORKERS est ${noisyworker_etat}" >> "/opt/monitoring-lab/plc/reports/run-${date}/services.txt"

echo "[+] Fin création des services > services.txt"

# logs

echo "[+] Lecture des logs"

echo "fake-api: " > /opt/monitoring-lab/plc/reports/run-${date}/journald.txt
journalctl -u fake-api -n 30 >> /opt/monitoring-lab/plc/reports/run-${date}/journald.txt

echo "" >> /opt/monitoring-lab/plc/reports/run-${date}/journald.txt
echo "log-generator: " >> /opt/monitoring-lab/plc/reports/run-${date}/journald.txt
journalctl -u log-generator -n 30 >> /opt/monitoring-lab/plc/reports/run-${date}/journald.txt

echo "fake-api: " > /opt/monitoring-lab/plc/reports/run-${date}/journald_error.txt
journalctl -u fake-api -n 30 | grep -E "ERROR|CRITICAL" >> /opt/monitoring-lab/plc/reports/run-${date}/journald_error.txt

echo "" >> /opt/monitoring-lab/plc/reports/run-${date}/journald_error.txt
echo "log-generator: " >> /opt/monitoring-lab/plc/reports/run-${date}/journald_error.txt
journalctl -u log-generator -n 30 | grep -E "ERROR|CRITICAL" >> /opt/monitoring-lab/plc/reports/run-${date}/journald_error.txt

echo "[+] Fin de la lecture des logs > journald.txt, journald_error.txt"

# cpu 

echo "[+] Observation des processus"

ps aux --sort=-%cpu | head -n 11 > /opt/monitoring-lab/plc/reports/run-${date}/top_cpu.txt
ps aux | grep cpu-hog >> /opt/monitoring-lab/plc/reports/run-${date}/hogs.txt

echo "[+] Fin de l'observation des processus > top_cpu.txt, hogs.txt"

# app sumary

echo "[+] Analyse de l'app log"

echo "Nombre total de lignes: " "$(wc -l < /var/log/monitoring-lab/data/app.log)" > "/opt/monitoring-lab/plc/reports/run-${date}/app_summary.txt"

echo "Nombre total de lignes ERROR: " \
"$(grep -c "ERROR" /var/log/monitoring-lab/data/app.log)" >> "/opt/monitoring-lab/plc/reports/run-${date}/app_summary.txt"

echo "Nombre total de lignes CRITICAL: " \
"$(grep -c "CRITICAL" /var/log/monitoring-lab/data/app.log)" >> "/opt/monitoring-lab/plc/reports/run-${date}/app_summary.txt"

echo "Top 5 des hôtes :" >> "/opt/monitoring-lab/plc/reports/run-${date}/app_summary.txt"

awk '$0 !~ /^#/ {print $3}' /var/log/monitoring-lab/data/app.log \
| sort \
| uniq -c \
| sort -nr \
| head -n 5 >> "/opt/monitoring-lab/plc/reports/run-${date}/app_summary.txt"

sed -E 's/(secret|password|token|key)=[a-zA-Z0-9_-]+/\1=REDACTED/gI' \
/var/log/monitoring-lab/data/app.log \
> /opt/monitoring-lab/plc/reports/run-${date}/app_redacted.txt

echo "[+] Fin de l'analyse de app.log > app_summary.txt, app_redacted.txt"

# metrics summary 

echo "[+] Analyse de metrics.csv"

echo "Total lignes: " \
"$(tail -n +2 /var/log/monitoring-lab/data/metrics.csv | wc -l)" \
> /opt/monitoring-lab/plc/reports/run-${date}/metrics_summary.txt

echo "Lignes cpu >= 95: " \
"$(awk -F',' 'NR>1 && $3+0 >= 95' /var/log/monitoring-lab/data/metrics.csv | wc -l)" \
>> /opt/monitoring-lab/plc/reports/run-${date}/metrics_summary.txt

echo "Lignes anormales: " \
>> /opt/monitoring-lab/plc/reports/run-${date}/metrics_summary.txt

awk -F',' 'NR>1 && $3+0 >= 95' /var/log/monitoring-lab/data/metrics.csv | head -n 5 \
>> /opt/monitoring-lab/plc/reports/run-${date}/metrics_summary.txt

echo "[+] Fin de l'analyse de metrics.csv > metrics_summary.txt"

# tree 

echo "[+] Check des fichiers tree"

find /var/log/monitoring-lab/tmp/tree/ -type f -name "*.bak" \
> /opt/monitoring-lab/plc/reports/run-${date}/tree_bak.txt

find /var/log/monitoring-lab/tmp/tree/ -type f \
| xargs grep -l "SECRET=" 2>/dev/null \
> /opt/monitoring-lab/plc/reports/run-${date}/tree_secret.txt

echo "[+] Fin du check des fichiers tree > tree_bak.txt, tree_secret.txt"

# controle des fichiers

echo "---------------------------------------------------------------------"

FILES=(
"/opt/monitoring-lab/plc/reports/run-${date}/services.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/journald.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/journald_error.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/top_cpu.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/hogs.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/app_summary.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/app_redacted.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/metrics_summary.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/tree_bak.txt"
"/opt/monitoring-lab/plc/reports/run-${date}/tree_secret.txt"
)

echo "Controle des fichiers : "

for file in "${FILES[@]}"
do
    if [[ -f "$file" ]]; then
        echo "[OK] $file"
    else
        echo "[MISSING] $file"
    fi
done