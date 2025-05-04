#!/bin/sh

# Verifica si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detectar sistema operativo BSD
detect_bsd() {
    uname -s
}

# Crear usuario según sistema BSD
add_bsd_user() {
    username=$1
    password=$2
    shell_path="/usr/local/bin/bash"

    os_name=$(detect_bsd)

    # Asegurarse que bash está en /etc/shells
    grep -q "$shell_path" /etc/shells || echo "$shell_path" >> /etc/shells

    echo "[$os_name] Añadiendo $username con bash"

    case "$os_name" in
        OpenBSD)
            useradd -m -s "$shell_path" "$username"
            encrypted=$(encrypt -b blowfish "$password")
            usermod -p "$encrypted" "$username"
            ;;
        NetBSD)
            useradd -m -s "$shell_path" "$username"
            echo "$username:$password" | chpasswd
            ;;
        FreeBSD)
            pw useradd "$username" -m -s "$shell_path"
            echo "$password" | pw usermod "$username" -h 0
            ;;
        *)
            echo "BSD desconocido: $os_name"
            return 1
            ;;
    esac

    # Verificación
    if id "$username" >/dev/null 2>&1; then
        echo "✔ Usuario $username creado"
    else
        echo "✘ Error creando $username"
    fi
}

# Verifica que seq exista
if ! command_exists seq; then
    echo "❌ El comando 'seq' no está instalado."
    exit 1
fi

echo "🔧 Comenzando la creación de usuarios..."

# Bucle principal
for i in $(seq -w 0 499); do
    username="user$i"
    password="qwerty$i"
    add_bsd_user "$username" "$password"
done

echo "✅ Finalizado."
