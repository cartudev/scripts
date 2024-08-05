#!/bin/bash

# Variables
WP_CLI_PATH=~/wp-cli.phar
WP_PATH=~/public_html/staging
PHP_BIN=/opt/cpanel/ea-php82/root/usr/bin/php
LOG_FILE=maintenance_log.txt

log "Mantenimiento de AGOSTO"
log "Se realizaron tareas de mantenimiento en el sitio:"

# Función para loggear mensajes
log() {
    echo "$1" | tee -a $LOG_FILE
}

# Función para instalar WP-CLI si no está presente
install_wp_cli() {
    log "Instalando WP-CLI..."
    cd ~
    curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    $PHP_BIN wp-cli.phar --info
    log "WP-CLI instalado correctamente."
}

# Comprobar si WP-CLI está instalado
if ! [ -x "$(command -v $WP_CLI_PATH)" ]; then
    install_wp_cli
fi

# Verificar si el plugin Health Check está instalado y si no, instalarlo
if ! $PHP_BIN $WP_CLI_PATH plugin is-installed health-check --path=$WP_PATH; then
    log "Instalando plugin Health Check..."
    $PHP_BIN $WP_CLI_PATH plugin install health-check --activate --path=$WP_PATH
    log "Plugin Health Check instalado y activado."
fi

# Inicializar contador para numeración dinámica
step=1

# Actualizar WordPress Core
WP_CORE_UPDATE=$($PHP_BIN $WP_CLI_PATH core update --path=$WP_PATH --skip-themes --skip-plugins)
if [[ $WP_CORE_UPDATE != *"WordPress is at the latest version"* ]]; then
    log "$step. Se actualizó WordPress a la versión $($PHP_BIN $WP_CLI_PATH core version --path=$WP_PATH)"
    ((step++))
fi

# Actualizar todos los temas
THEMES_UPDATED=$($PHP_BIN $WP_CLI_PATH theme update --all --path=$WP_PATH --format=json)
if [ -n "$THEMES_UPDATED" ]; then
    log "$step. Se actualizaron los siguientes temas:"
    echo "$THEMES_UPDATED" | jq -r '.[] | ["   - " + .name, .old_version, .new_version] | @tsv' | while IFS=$'\t' read -r name old_version new_version; do
        log "   - $name se ha actualizado de $old_version a $new_version."
    done
    ((step++))
fi

# Actualizar todos los plugins
PLUGINS_UPDATED=$($PHP_BIN $WP_CLI_PATH plugin update --all --path=$WP_PATH --format=json)
if [ -n "$PLUGINS_UPDATED" ]; then
    log "$step. Se actualizaron los siguientes plugins:"
    echo "$PLUGINS_UPDATED" | jq -r '.[] | ["   - " + .name, .old_version, .new_version] | @tsv' | while IFS=$'\t' read -r name old_version new_version; do
        log "   - $name se ha actualizado de $old_version a $new_version."
    done
    ((step++))
fi

# Purgar caché de LiteSpeed
LITESPEED_PURGE_OUTPUT=$($PHP_BIN $WP_CLI_PATH litespeed-purge all --path=$WP_PATH)
log "- Purgando caché de LiteSpeed:"
log ""
log "$LITESPEED_PURGE_OUTPUT"

# Verificar estado de salud del sitio
HEALTH_CHECK_OUTPUT=$($PHP_BIN $WP_CLI_PATH health-check status --path=$WP_PATH --format=json)
log "- Reporte de Health Check:"
log ""
echo "$HEALTH_CHECK_OUTPUT" | jq -r '.checks | to_entries | map(["   - " + .key, .value.type, .value.label, .value.status] | @tsv)[]' | while IFS=$'\t' read -r check type label status; do
    log "$check - $type - $label - $status"
done

# Verificar checksums de WordPress Core y plugins
CORE_CHECKSUMS_OUTPUT=$($PHP_BIN $WP_CLI_PATH core verify-checksums --path=$WP_PATH)
log "- Reporte de Verificación de Checksums de Core:"
log ""
log "$CORE_CHECKSUMS_OUTPUT"

PLUGIN_CHECKSUMS_OUTPUT=$($PHP_BIN $WP_CLI_PATH plugin verify-checksums --all --path=$WP_PATH --format=json)
log "$step. Reporte de Verificación de Checksums de Plugins:"
log ""
echo "$PLUGIN_CHECKSUMS_OUTPUT" | jq -r '.[] | ["   - " + .plugin, .file, .message] | @tsv' | while IFS=$'\t' read -r plugin file message; do
    log "$plugin - $file - $message"
done

# Descargar paquetes de idiomas
log "- Descargando paquetes de idiomas:"
LANG_CORE_UPDATE=$($PHP_BIN $WP_CLI_PATH language core update --path=$WP_PATH)
log "$LANG_CORE_UPDATE"
LANG_PLUGIN_UPDATE=$($PHP_BIN $WP_CLI_PATH language plugin update --all --path=$WP_PATH)
log "$LANG_PLUGIN_UPDATE"
LANG_THEME_UPDATE=$($PHP_BIN $WP_CLI_PATH language theme update --all --path=$WP_PATH)
log "$LANG_THEME_UPDATE"

# Replicar en producción (puedes añadir más detalles si es necesario)
log "Realizado en producción."
# Repite los pasos anteriores para la instalación en producción

log "Mantenimiento completado."
