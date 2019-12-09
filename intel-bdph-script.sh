#! /bin/sh

#Função que dá echo em caso de erro.
echoerr() { echo "$@" 1>&2; }

#Testar se os pré-requisitos existem:

# 1 - Testar awk
(which awk >> /dev/null 2>&1 ) || { echoerr 'ERRO: É necessário instalar o AWK no seu sistema operacional.'; exit 1; }

# 2 - Testar se o processador é Intel (procurar GenuineIntel no /proc/cpuinfo)
(awk 'BEGIN { found_intel=1 }
     $1=="vendor_id" { if ($3 == "GenuineIntel") found_intel=0 }
     END {exit found_intel}' /proc/cpuinfo) || { echoerr 'ERRO: Sua CPU não é da Intel'; exit 63; }

# 3 - Testar se as msr-tools existem
INSTALADAS=0
for cmd in 'which rdmsr' 'which wrmsr'; do
    (eval $cmd >> /dev/null 2>&1) || INSTALADAS=1
done
[ $INSTALADAS -ne 0 ] && { echoerr 'ERRO: É necessário instalar as msr-tools no seu sistema operacional.'; exit 1; }

# 4 - Alerta para macs
(grep Mac /sys/devices/virtual/dmi/id/product_name) && {
    echo 'Detectamos que você está possivelmente usando um Mac. Caso esteja, instale o pacote macfanctld para melhores resultados.'
}

if [ "$EUID" -ne 0 ]; then
    echo 'Você é um usuário normal. Confirme sua senha para continuar como root.'
    # Se estivermos em um terminal, SUDO. Se não, interface gráfica.
    if [ -t 1 ]; then sudo /bin/sh $0; else pkexec /bin/sh $0; fi
else
    # 5 - Linux tools
    (grep -i 'buntu\|mint\|zorin' /etc/*release* >> /dev/null 2>&1 || grep -R ubuntu /etc/apt/ >> /dev/null 2>&1) && { # procurar Ubuntu
        (dpkg -l linux-tools-$(uname -r) >> /dev/null 2>&1) || { # confirmar se já está instalado
            echo "Recomenda-se a instalação das ferramentas de kernel nos sistemas de base Ubuntu. Rodando sudo apt install linux-tools-$(uname -r)...";
            apt install linux-tools-$(uname -r) || echoerr "ALERTA: O pacote linux-tools-$(uname -r) não foi instalado corretamente. O script pode não funcionar."; };
    }
    # Testar se o script já foi rodado neste boot (pasta /tmp é resetada a cada boot)
    [ -f '/tmp/intel-bdph-script' ] && {
    echoerr 'ERRO: Esse script já foi rodado nessa máquina!';
    echoerr 'Se tem certeza de que deseja rodá-lo novamente, remova o arquivo /tmp/intel-bdph-script';
    exit 2; }

    echo 'Carregando o módulo de kernel do MSR...'
    (modprobe msr) || { echoerr 'ERRO: Não foi possível inserir o módulo do MSR no kernel.' ; exit 3; }

    echo 'Lendo o registro PROCHOT do processador...'
    regist=$(rdmsr 0x1FC)
    [ $? -ne 0 ] && { echoerr 'ERRO: Não foi possível obter os conteúdos do registro BD_PROCHOT.' ; exit 4; }

    echo 'Escrevendo no registro do processador...'
    (wrmsr 0x1FC $(printf '%s' "$regist" | awk '{
        match($0,"[0-9]+")
        num=substr($0,RSTART,RLENGTH)-1
        match($0,"[a-z]+")
        let=substr($0,RSTART,RLENGTH)
        print num""let
        }')) || { echoerr 'ERRO: Não foi possível desativar BD_PROCHOT.' ; exit 5; }
    
    echo 'Finalizado. Pondo um arquivo-flg na pasta /tmp.'
    # Marcar que já foi escrito nesse boot
    touch /tmp/intel-bdph-script
fi
