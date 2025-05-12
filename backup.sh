#!/bin/sh
# autor: Marcos Menduiña Macias
# autor: Emilio Jose Pulpeiro Rodriguez
# Script copia de seguridad de usuario

BACKUP_DIR=/var/backups
if [ "$(uname -s)" = "FreeBSD" ]; then
    COMPRESOR=$(which bzip2)
else
    COMPRESOR=/bin/bzip2
fi
COMPRESOR_EXT="bz2"

# Obtener UID mínimo desde usuario base
MINUID=$(grep ^usuario /etc/passwd | cut -f3 -d:)
if [ -z "$MINUID" ]; then
    if [ -f /etc/login.defs ]; then
        MINUID=$(grep "^UID_MIN" /etc/login.defs | awk '{print $2}')
    elif [ -f /etc/release ] && grep -q "Solaris" /etc/release; then
        MINUID=100
    elif uname -s | grep -q "BSD"; then
        MINUID=1000
    else
        MINUID=1000
    fi
fi

# Crear el directorio de backups si no existe
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR" || {
        logger -p user.warning "No se pudo crear $BACKUP_DIR"
        exit 1
    }
fi

# Comprobación de espacio
check_space() {
    user_home=$1
    required=$(du -s "$user_home" | awk '{print $1}')
    required=$(($required + ($required / 10)))

    available=$(df -k "$BACKUP_DIR" | awk 'NR==2 {print $4}')
    [ "$available" -ge "$required" ]
}

# Fecha actual (para comprobar si ya hay backup ese día)
TODAY=$(date +%Y-%m-%d)

# Proceso principal
cat /etc/passwd | while IFS=: read username x uid gid x homedir shell; do
    [ "$uid" -lt "$MINUID" ] && continue
    [ ! -d "$homedir" ] && continue

    if [ -f "$homedir/.backupDAY" ] || [ -f "$homedir/.backupWEEK" ]; then
        if [ -f "$homedir/.backupWEEK" ]; then
            [ "$(date +%w)" -ne 0 ] && continue
        fi

        user_backup_dir="$BACKUP_DIR/$username"
        [ ! -d "$user_backup_dir" ] && {
            mkdir -p "$user_backup_dir"
            chmod 700 "$user_backup_dir"
            chown "$username:$(id -gn "$username" 2>/dev/null || echo "$username")" "$user_backup_dir"
        }

        backup_file="$user_backup_dir/${username}.tar"
        if [ -f "${backup_file}.${COMPRESOR_EXT}" ]; then
            logger -p user.warning "Ya existe copia de $username hoy"
            continue
        fi

        if ! check_space "$homedir"; then
            logger -p user.warning "Espacio insuficiente para backup de $username"
            continue
        fi

        if tar -cf "$backup_file" -C "$(dirname "$homedir")" "$(basename "$homedir")"; then
            if "$COMPRESOR" "$backup_file"; then
                chmod 600 "${backup_file}.${COMPRESOR_EXT}"
                chown "$username:$(id -gn "$username" 2>/dev/null || echo "$username")" "${backup_file}.${COMPRESOR_EXT}"
                logger -p user.notice "Backup de $username completado"
            else
                logger -p user.warning "Error al comprimir backup de $username"
                rm -f "$backup_file"
            fi
        else
            logger -p user.warning "Error al crear backup tar de $username"
        fi
    fi
done

exit 0
