#!/bin/bash

# Bucle para borrar usuarios del user005 al user499
for i in $(seq -f "user%03g" 5 499); do
    # Verificar si el usuario existe
    if id "$i" &>/dev/null; then
        echo "Borrando el usuario: $i"
        # Borrar el usuario y su directorio home
        userdel -r "$i"
    else
        echo "El usuario $i no existe, no se puede borrar."
    fi
done
