#! /bin/sh

# Para dar echo em caso de erro
echoerr() { echo "$@" 1>&2; }

# Teste de root.
[ $(id -u) -ne 0 ] && {
    echo 'Você está rodando como um usuário normal. Digite sua senha para continuar como root.'
    if [ -t 1 ]; then sudo /bin/sh $0; else pkexec /bin/sh $0; fi
    [ $? -ne 0 ] && {
        echoerr 'Erro ao assumir root.'
        exit 127
    }
    exit 127 # sem root a gente não faz nada
}

### Pré - requisitos ###

# 1 - Testar AWK
which awk || {
    echoerr 'ERRO: É necessário instalar o AWK no seu sistema operacional.'
    exit 1
}

# 2 - Testar Intel
awk 'BEGIN { found_intel=1 }
     $1=="vendor_id" { if ($3 == "GenuineIntel") found_intel=0 }
     END {exit found_intel}' /proc/cpuinfo || {
    echoerr 'ERRO: Sua CPU não é da Intel'
    exit 1
}

# 3 - Testar MSR-Tools
(which wrmsr >> /dev/null 2>&1 && which rdmsr >> /dev/null 2>&1 && modinfo msr >> /dev/null 2>&1) || {
    echoerr 'ERRO: É necessário instalar as msr-tools no seu sistema operacional.'
    exit 1
}

# 4 - Alerta para macs
(grep Mac /sys/devices/virtual/dmi/id/product_name >> /dev/null 2>&1 && !(which macfanctld) ) && {
        echo -n "Recomenda-se a instalação do gerenciador de ventoinha para Macs (macfanctld)."
}

# 5 - Linux tools
(grep -i 'buntu\|mint\|zorin' /etc/*release* >> /dev/null 2>&1 || grep -R ubuntu /etc/apt/ >> /dev/null 2>&1) && { # procurar Ubuntu
    echo "Recomenda-se a instalação das ferramentas de kernel nos sistemas de base Ubuntu. Para isso, rode $ sudo apt install linux-tools-$(uname -r)."
    echo 'Ignore o aviso acima caso elas já estejam instaladas.';
}

### CÓDIGOS ###

# Verificar se já executamos nesse boot.
[ -f '/tmp/intel-bdph-script' ] && {
    echoerr 'ERRO: Esse script já foi rodado nessa máquina!'
    echoerr 'Se tem certeza de que deseja rodá-lo novamente, remova o arquivo /tmp/intel-bdph-script'
    exit 2
}

echo 'Carregando o módulo de kernel do MSR...'
modprobe msr || {
    echoerr 'ERRO: Não foi possível inserir o módulo do MSR no kernel.'
    exit 3
}

echo 'Lendo o registro PROCHOT do processador...'
regist=$(rdmsr 0x1FC)
[ $? -ne 0 ] && {
    echoerr 'ERRO: Não foi possível obter os conteúdos do registro BD_PROCHOT.'
    exit 4
}

echo 'Escrevendo no registro do processador...'
wrmsr 0x1FC $(printf '%s' "$regist" | awk '{
 match($0,"[0-9]+")
 num=substr($0,RSTART,RLENGTH)-1
 match($0,"[a-z]+")
 let=substr($0,RSTART,RLENGTH)
 print num""let
 }') || {
    echoerr 'ERRO: Não foi possível desativar BD_PROCHOT.'
    exit 5
}

echo 'Finalizado. Pondo um arquivo-flag na pasta /tmp.'
touch /tmp/intel-bdph-script
