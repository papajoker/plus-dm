#!/usr/bin/env bash
#/etc/X11/xinit/xinitrc.d/plus-dm.sh

export default_session='TTY'
export dm_timer=8
declare -r pkgname='plus-dm'

## default string constants {{{
declare -A txt=(
    ['title']="Environment choise"
    ['label']='Choose the desktop'
    ['validate']='validate'
    ['choise']='The choise'
    ['error']='Error'
)
lg=$(locale 2>/dev/null | awk -F'=' '/^LANG/ {print $2}')
lg=${lg:0:2}
dico="/usr/share/locale/$lg/LC_MESSAGES/$pkgname"
[ -f "$dico" ] && source "$dico"
# }}}

#liste des bureaux
declare -a SYS=( )
#liste des commandes
declare -A SYSTEMES=(['TTY']='clear && exit')

# function de debug
# en prod commenter logger et echo
function echod {
	logger $1
	#echo $1
}

# recherche automatique des bureaux présent dans la distribution
function getDE {
 local name=''		#label de la commande
 local value=''		#commande a executer
 local desktop=''	#fichier .desktop
 
 #parcourir le répertoire 
 for desktop in /usr/share/xsessions/*.desktop; do
	# nom du fichier enregistré dans la variable $desktop
	# lecture dans le fichier
	name=$(awk -F'=' '/^Name[ ]{0,}=/ {print $2}' $desktop)
	value=$(awk -F'=' '/^Exec[ ]{0,}=/ {print $2}' $desktop)
    name=${name// /_}
		# sauvegarde du label et valeur dans les 2 tableaux
		SYSTEMES["$name"]="exec $value"
		SYS=( ${SYS[*]} "$name" )
 done
}

#lire fichier perso .conf passé en paramètre
function getConfig {
	local name=''		#label de la commande
	local value=''		#commande a executer
	local line=''		#ligne du fichier de conf
	local conf_file="$HOME/.config/$1"
	
	# fichier conf existe ?
	if [ ! -f "$conf_file" ]; then
		echod "INFO: fichier "$conf_file" de configuration inexistant"
		# recherche automatique
		getDE
		return 1
        # sauvegarde dans un nouveau fichier conf ?
	fi
	# lire chaque ligne du fichier
	while read line; do
		line="$( sed -r -e 's/[[:space:]]*#.*$//; //d;'              \
                        -e 's/=/ = /;' -e 's/[[:space:]]+=[[:space:]]+/=/'  \
                        <<<"${line}" )"
		name="${line%%=*}"
        value="${line#*=}"
        if [ "$name" != "$value" ]; then
            name=${name// /_}
            # sauvegarde du label et valeur dans les 2 tableaux
			SYSTEMES["$name"]="$value"
			SYS=( ${SYS[*]} "$name" )
        fi
	done <"${conf_file}"
}

#affiche le tableau SYS pour choisir un bureau
function dialogx {
	local title="$1"
	local label="$2"
	local choise='TTY'
	
	if [ -f '/usr/bin/kdialog' ]; then
		choise=$(kdialog --combobox "$label" "${SYS[@]}" \
			--default "$default_session" \
			--title "$title")
	else
		#unset SYS["$default_session"]
		choise=$(zenity --title "$title" --entry --text="$label" \
			--timeout=$dm_timer \
			--ok-label="${txt[validate]}"	--cancel-label="TTY" \
			--entry-text="$default_session" "${SYS[@]}" 2> /dev/null)
	fi  
	echo $choise
}

###--- run ---###

function runDM
{
    getConfig "plus-dm.menu.conf"
    #getDE

    # pour debug : journalctl -t <mon_login>
    for i in "${SYS[@]}"; do echod "SYS: $i"; done
    for i in "${SYSTEMES[@]}"; do echod "SYSTEMES: $i"; done

	if [ -n "$DESKTOP_SESSION" ]; then
		# utilisateur a passé directement un label de bureau dans env (avec export )
		if [ -n "${SYSTEMES[$DESKTOP_SESSION]}" ]; then
			${SYSTEMES[$DESKTOP_SESSION]}
			exit 0
		fi
	fi

    choise=$(dialogx "${txt[title]}" "${txt[label]}:")
    echod "${txt[choise]}: $choise"

    if [ -n "${SYSTEMES[$choise]}" ]; then
            # sauvegarde de la valeur choisie comme "default_session" dans ce script
            reg="default_session='$default_session'/default_session='$choise'"
            sed -i -e "s/$reg/" "$HOME/.xinitrc"
            # executer la commande dans le tableau SYSTEMES placée à l'index $choise
            ${SYSTEMES[$choise]}  
    else
            # executer la commande dans le tableau SYSTEMES placée à l'index "TTY"
            ${SYSTEMES[TTY]}
    fi
    exit 0
}
export -f runDM

