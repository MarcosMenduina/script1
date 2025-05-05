#!/bin/sh
# Script para añadir 500 usuarios

# Comando disponible?
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Generar contraseña según el sistema
generate_password() {
    username=$1
    password=$2
    
    if command_exists mkpasswd; then
        # Usar mkpasswd si está disponible (Linux)
        encrypted_password=$(mkpasswd -m md5 "$password")
        echo "$encrypted_password"
    else
        # Fallback para sistemas sin mkpasswd
        echo "$password"
    fi
}

# Añadir un usuario según SO
add_user() {
    username=$1
    password=$2
    
    echo "Creando usuario: $username con contraseña: $password"
    
    if [ -f /etc/debian_version ] || [ -f /etc/fedora-release ] || [ -f /etc/redhat-release ] || [ -f /etc/lsb-release ]; then
        # Sistemas Linux (Devuan, Fedora, Ubuntu)
        if command_exists mkpasswd; then
            encrypted_password=$(generate_password "$username" "$password")
            sudo useradd -m -s /bin/bash -p "$encrypted_password" "$username"
        else
            # Método alternativo si mkpasswd no está disponible
            useradd -m -s /bin/bash "$username"
            echo "$username:$password" | chpasswd
        fi
    elif [ -f /etc/release ] && grep -q "Solaris" /etc/release; then
        # Solaris
        useradd -d "/export/home/$username" -m -s /bin/bash "$username"
        # Para Solaris, podemos usar el script expect
        if [ -f ./pass.expect ]; then
            ./pass.expect "$username" "$password"
        else
            echo "$username:$password" | passwd -i
        fi
    elif uname -s | grep -q "BSD"; then
        # Sistemas BSD (OpenBSD, NetBSD, FreeBSD)
        os_name=$(uname -s)
        case "$os_name" in
            "OpenBSD")
                useradd -m -s /bin/ksh "$username"
                encrypted=$(encrypt -b 8 "$password")
		usermod -p "$encrypted" "$username"
                ;;
            "NetBSD")
    		useradd -m -s /bin/sh "$username"
    		encrypted=$(openssl passwd -1 "$password")
    		usermod -p "$encrypted" "$username"
                ;;
            "FreeBSD")
                pw useradd "$username" -m -s /bin/sh
                echo "$password" | pw usermod "$username" -h 0
                ;;
            *)
                echo "BSD desconocido: $os_name"
                return 1
                ;;
        esac
    else
        echo "SO desconocido, no se puede añadir el usuario $username"
        return 1
    fi
    
    # Verificar si se creó bien
    if id "$username" >/dev/null 2>&1; then
        echo "Usuario $username creado correctamente"
        return 0
    else
        echo "Error al crear el usuario $username"
        return 1
    fi
}

if ! command_exists seq; then
    echo "Error: El comando 'seq' no está instalado. Instálalo antes de continuar."
    exit 1
fi

echo "Iniciando proceso de creación de usuarios..."

# Crear usuarios del user000 al user499 usando seq
for i in $(seq -f "%03g" 0 499); do
    username="user$i"
    password="qwerty$i"
    add_user "$username" "$password"
done

echo "Creación de usuarios completada."
