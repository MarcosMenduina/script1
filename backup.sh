#!/bin/sh
# autor: Marcos Menduiña Macias
# autor: Emilio Jose Pulpeiro Rodriguez
# Script copia de sguridad de usuario

# variables de configuración
BACKUP_DIR=/var/backups
if [ "$(uname -s)" = "FreeBSD" ]; then
    COMPRESOR=$(which bzip2)
else
    COMPRESOR=/bin/bzip2
fi
COMPRESOR_EXT="bz2"  # Extension para comprimir archivos (usamos bz2)

# Mínimo UID de usuario
MINUID=$(cat /etc/passwd | grep ^usuario | cut -f3 -d:)

# En caso de que usuario no existiese (no es nuestro caso) buscar un default adecuado
if [ -z "$MINUID" ]; then
    # Mínimo UID de cada SO
    if [ -f /etc/login.defs ]; then
        # Linux
        MINUID=$(grep "^UID_MIN" /etc/login.defs | awk '{print $2}')
    elif [ -f /etc/release ] && grep -q "Solaris" /etc/release; then
        # Solaris, usa 100
        MINUID=100
    elif uname -s | grep -q "BSD"; then
        # BSDs, usan 1000
        MINUID=1000
    else
        MINUID=1000
    fi
fi

# Asegurarnos de q existe el directorio de backup
if [ ! -d "$BACKUP_DIR" ]; then
    mkdir -p "$BACKUP_DIR"
    if [ $? -ne 0 ]; then
        logger -p user.warning "No se puede crear el directorio backup $BACKUP_DIR"
        exit 1
    fi
fi

# Comprobar espacio disponible
check_space() {
    user_home=$1
    required_space=$(du -s "$user_home" | awk '{print $1}')
    
    # Se requiere un 10% más por la compresión
    required_space=$(($required_space + ($required_space / 10)))
    
    # Espacio disponible en directorio backup (BACKUP_DIR)
    if [ "$(uname -s)" = "SunOS" ]; then
        # Solaris
        available_space=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    else
        # Linux y BSD
        available_space=$(df -k "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    fi
    
    if [ "$available_space" -lt "$required_space" ]; then
        return 1  # No hay espacio suficiente
    else
        return 0
    fi
}

# Fecha actual en formato YYYY-MM-DD
TODAY=$(date +%Y-%m-%d)

# Proceso para cada usuario
cat /etc/passwd | while IFS=: read username x uid gid x homedir shell; do
    # Skippear si UID es menor que MINUID, el UID de "usuario"
    if [ "$uid" -lt "$MINUID" ]; then
        continue
    fi
    
    # Skippear si el directorio home no existe
    if [ ! -d "$homedir" ]; then
        continue
    fi
    
    # Comprobar si usuario quiere hacer copia de seguridad (diaria o semanal)
    if [ -f "$homedir/.backupDAY" ] || [ -f "$homedir/.backupWEEK" ]; then
        # Para las semanales: hacerla el domingo (day 0)
        if [ -f "$homedir/.backupWEEK" ]; then
            day_of_week=$(date +%w)
            if [ "$day_of_week" -ne 0 ]; then
                continue
            fi
        fi
        
        # Crear directorio backup del usuario si no existe
        user_backup_dir="$BACKUP_DIR/$username"
        if [ ! -d "$user_backup_dir" ]; then
            mkdir -p "$user_backup_dir"
            # Solo root y usuario pueden acceder
            chmod 700 "$user_backup_dir"
            chown "$username:$(id -gn "$username" 2>/dev/null || echo "$username")" "$user_backup_dir"
        fi
        
        # No realizar más de una copia al día por usuario
        if [ -f "$user_backup_dir/${TODAY}_${username}.tar.$COMPRESOR_EXT" ]; then
            logger -p user.warning "El backup para usuario $username ya existe hoy"
            continue
        fi
        
        # Comprobar espacio suficiente
        if ! check_space "$homedir"; then
            logger -p user.warning "Espacio insuficiente para hacer backup de $username"
            continue
        fi
        
        # Crear el backup
        backup_file="$user_backup_dir/${TODAY}_${username}.tar"
        
        # Crear el fichero tar
        if tar -cf "$backup_file" -C "$(dirname "$homedir")" "$(basename "$homedir")" 2>/dev/null; then
            # Comprimirlo
            if "$COMPRESOR" "$backup_file" 2>/dev/null; then
                # Permisos para que solo root y el usuario puedan acceder
                chmod 600 "$backup_file.$COMPRESOR_EXT"
                chown "$username:$(id -gn "$username" 2>/dev/null || echo "$username")" "$backup_file.$COMPRESOR_EXT"
                # Mensajes con logger
                logger -p user.notice "Backup para usuario $username completado"
            else
                logger -p user.warning "Error al comprimir el backup para usuario $username"
                rm -f "$backup_file"
            fi
        else
            logger -p user.warning "Error al crear el backup tar para usuario $username"
        fi
    fi
done

exit 0
