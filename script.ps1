param (

    [string]$archivo = $(Read-Host "Indica la ruta al fichero .csv con los datos de la estructura")

)

#Comprueba si se han proporcionado un archivo .csv y es válido
if (-not $archivo -or -not $archivo.endsWith(".csv")) {
    return Write-Host -ForegroundColor Red "Error de sintaxis. Debes proporcionar un archivo .csv válido"
}

#Obtiene información sobre el sistema operativo, para posteriormente evaluar su tipo de producto
$infoSO = Get-CimInstance -ClassName Win32_OperatingSystem

#Comprueba si el dispositivo que ejecuta el script es un controlador de dominio en función del número de producto (2 = Domain Controller)
if ($infoSO.ProductType -ne 2) {
    return Write-Host -ForegroundColor Red "Este dispositivo no es un controlador de dominio"
}

#Almacena el nombre distinguido del controlador de dominio
$dc = Get-ADDomain | Select-Object -ExpandProperty DistinguishedName

#Importa el archivo .csv con los datos de la estructura
try {
    $csv = Import-CSV -Path $archivo
} catch {
    return Write-Host -ForegroundColor Red $_.Exception.Message
}

$raiz = "C:\"

#Comprueba si C:\ existe y en caso negativo, la raiz será la unidad desde la que se ejecuta el script
if (-not (Test-Path $raiz)) {
    $raiz = (Get-Item $(Get-Location)).PSDrive.Name + ':\'
}

#Funcion para crear una OU y su respectivo grupo
function crearOU ($nombre, $rutaOU, $descripcion, $ruta, $padre) {

    #Para crear la OU
    if (Get-ADOrganizationalUnit -Filter "distinguishedName -eq 'OU=$nombre,$rutaOU'") { #Si la OU ya existe, omite
        Write-Host -ForegroundColor Yellow "La OU $nombre ya existe. Se omitirá este paso"
    } else { #Sino, la crea
        Write-Host "Creando la OU $nombre ..."
        try {
            New-ADOrganizationalUnit -Name "$nombre" -Path "$rutaOU" -Description "$descripcion" -ProtectedFromAccidentalDeletion $false
            Write-Host -ForegroundColor Green "¡La OU $nombre ha sido creada satisfactoriamente!"
        } catch {
            Write-Host -ForegroundColor Red $_.Exception
        }
    }

    #Para crear el grupo
    if (Get-ADGroup -Filter "name -eq '$nombre'" -SearchBase $rutaOU) { #Si el grupo existe, omite
	    Write-Host -ForegroundColor Yellow "El grupo $nombre ya existe. Se omitirá este paso"
    } else { #Sino, lo crea
	    Write-Host "Creando el grupo $nombre en la OU $nombre ..."
        try {
            New-ADGroup -Name $nombre -GroupScope Global -Path "OU=$nombre,$rutaOU"
            Write-Host -ForegroundColor Green "¡Grupo $nombre creado satisfactoriamente!"

            if ($padre) {
                $grupoPadre = Get-ADGroup "CN=$padre,$rutaOU" #Obtiene el grupo padre
                $grupoHijo = Get-ADGroup -Filter "name -eq '$nombre'" -SearchBase $rutaOU #Obtiene el grupo hijo
                Add-ADGroupMember $grupoPadre -Members $grupoHijo
                Write-Host -ForegroundColor Green "¡Grupo $nombre añadido satisfactoriamente al grupo $padre!"
            }
        } catch {
            return Write-Host -ForegroundColor Red $_.Exception
        }
    }
}

#Funcion crear un usuario y aadirlo a su respectivo grupo
function crearUsuario ($usuario, $nivel, $rutaOU) {

    #Se crean dos variables, una que almacenará el username del usuario y otra que almacenará el dominio. Juntas formarán el nombre completamente cualificado del usuario
    $domain = ($dc.Substring(3)).replace(",DC=",".").toLower()

    if (Get-ADUser -Filter "name -eq '$usuario'" -SearchBase $rutaOU) { #Si el usuario existe, omite
	    Write-Host -ForegroundColor Yellow "El usuario $($usuario) ya existe. Se omitirá este paso"
    } else { #Sino, lo crea y lo añade a su respectivo grupo
        try {
            Write-Host "Creando usuario $($usuario) ...."
            New-ADUser -Name $usuario -Path $rutaOU -SamAccountName $usuario -UserPrincipalName "$usuario@$domain" -EmailAddress "$usuario@$domain" -AccountPassword (ConvertTo-SecureString "P@`$`$w0rd" -AsPlainText -Force) -GivenName $usuario -ChangePasswordAtLogon $true -Enabled $true
            Write-Host -ForegroundColor Green "¡Usuario $($usuario) creado correctamente!"
        } catch {
            return Write-Host -ForegroundColor Red $_.Exception
        }

        $grupo = Get-ADGroup "CN=$nivel,$rutaOU" #Obtiene el grupo al que será añadido el nuevo usuario

        if ($grupo) { #Si el grupo existe, añade el usuario al grupo
            try {
                Write-Host "Uniendo a $($usuario) al grupo $($grupo.name) ...."
                $member = "CN=$usuario,$rutaOU" #Almacena la ruta del usuario
                Add-ADGroupMember $grupo -Members $member
            } catch {
                return Write-Host -ForegroundColor Red $_.Exception
            }
        } else { #Sino, omite
            Write-Host -ForegroundColor Yellow "El grupo no existe. Se omitirá este paso"
        }
    }
}

#Función para crear la estructura de carpetas
function crearCarpeta ($ruta, $permisos, $recursoCompartido, $nivel1) {
    try {
        
        #Comprueba si la carpeta ya existe, sino la crea
        if (-not (Test-Path $ruta)) {
            Write-Host "Creando el directorio $ruta ...."
            New-Item $ruta -ItemType "directory" | Out-Null #Se crea el directorio
            Write-Host -ForegroundColor Green "¡Directorio $ruta creado correctamente!"
            
            #Asigna permisos locales
            Write-Host "Asignando permisos locales a $ruta ..." 
            foreach ($perm in $permisos) {
	            Invoke-Expression -Command:"icacls $ruta $perm" | Out-Null
            }
            Write-Host -ForegroundColor Green "¡Permisos locales asignados correctamente a $ruta!"
        } else {
            Write-Host -ForegroundColor Yellow "La carpeta $ruta ya existe. Se omitirá este paso"
        }

        #Comprueba si la carpeta ya está compartida, sino la comparte
        if ($recursoCompartido -and -not (Get-SMBShare -name $recursoCompartido -erroraction "silentlycontinue")) { #Se comprueba si el recurso está compartido, sino lo comparte
            Write-Host "Compartiendo $recursoCompartido ..."
            New-SMBShare -name $recursoCompartido -Path $ruta -FullAccess "Administrador", "Admins. del dominio", $nivel1 | Out-Null
            Write-Host -ForegroundColor Green "¡$recursoCompartido compartido correctamente!"
        } else {
            Write-Host -ForegroundColor Yellow "El recurso $recursoCompartido ya ha sido compartido. Se omitirá este paso"
        }
    } catch {
        return Write-Host -ForegroundColor Red $_.Exception
    }
}

#ITERACIÓN PARA CADA FILA DEL FICHERO .CSV
function iterarAchivo($activeDirectory) {
    $fila = 1 #Inicializa un contador para saber en que fila del .csv se encuentra el loop 
    foreach ($linea in $csv) {
    
        Write-Host "#$fila - - - - - - - - - - - - - - - - -"

        #CREACIÓN DE OU's
        #Comprueba que la OU de nivel 1 requerida existe y tiene carpetas base, sino crea la OU y las carpetas base
        if ($linea.nivel1) {
            if ($activeDirectory) {
                crearOU -nombre $linea.nivel1 -rutaOU $dc -descripcion $linea.nivel1_descripcion
            } else {
                #Crea un array para almacenar los permisos que se grabarán
                $permisosTotales = @("/inheritance:r", "/GRANT Administrador:'(OI)(CI)F'", "/GRANT 'Admins. del dominio:(OI)(CI)F'", "/GRANT $($linea.nivel1):'(OI)(CI)(GR,RD,RA,REA)'", "/GRANT $($linea.nivel1):'(WD,AD,WA,WEA,DE,DC,X)'")

                #Para cada grupo de nivel 3 perteneciente al grupo de nivel 2 se añadirá una denegación explícita de la escritura
                $subGrupos = Get-ADGroupMember $linea.nivel1 | Where-Object objectClass -eq "group"
                foreach ($grupo in $subGrupos) {
                    $permisosTotales += ,@("/DENY $($grupo.name):'(WD,AD,WA,WEA,DE,DC,X)'")
                }

                crearCarpeta -ruta "$($raiz)$($linea.nivel1)" -permisos $permisosTotales -recursoCompartido "$($linea.nivel1)_COMPANY" -nivel1 $linea.nivel1
                crearCarpeta -ruta "$($raiz)$($linea.nivel1)_USERS" -permisos @("/inheritance:r", "/GRANT Administrador:'(OI)(CI)F'", "/GRANT 'Admins. del dominio:(OI)(CI)F'", "/GRANT $($linea.nivel1):'(GR,RD,RA,REA)'") -recursoCompartido "$($linea.nivel1)_USERS$" -nivel1 $linea.nivel1
                crearCarpeta -ruta "$($raiz)$($linea.nivel1)_PROFILES" -permisos @("/inheritance:r", "/GRANT Administrador:'(OI)(CI)F'", "/GRANT 'Admins. del dominio:(OI)(CI)F'", "/GRANT $($linea.nivel1):'(GR,RD,RA,REA)'") -recursoCompartido "$($linea.nivel1)_PROFILES$" -nivel1 $linea.nivel1
                #crearCarpeta -ruta "$($raiz)$($linea.nivel1)_FOLDERS" -permisos @("/inheritance:r", "/GRANT Administrador:'(OI)(CI)F'", "/GRANT 'Admins. del dominio:(OI)(CI)F'", "/GRANT $($linea.nivel1):'(GR,RD,RA,REA)'") -recursoCompartido "$($linea.nivel1)_FOLDERS$" -nivel1 $linea.nivel1
            }
	    }

        #Comprueba que la OU de nivel 2 requerida existe y tiene carpeta, sino crea la OU y la carpeta
        if ($linea.nivel2) {
            if ($activeDirectory) {
                crearOU -nombre $linea.nivel2 -rutaOU "OU=$($linea.nivel1),$($dc)" -descripcion $linea.nivel2_descripcion -ruta "$($raiz)$($linea.nivel1)\$($linea.nivel2)" -padre $linea.nivel1
            } else {
                #Crea un array para almacenar los permisos que se grabarán
                $permisosTotales = @("/GRANT $($linea.nivel2):'(GR,RD,RA,REA,WD,AD,WA,WEA,DE,DC,X)'")

                #Para cada grupo de nivel 3 perteneciente al grupo de nivel 2 se añadirá una denegación explícita de la escritura
                $subGrupos = Get-ADGroupMember $linea.nivel2 | Where-Object objectClass -eq "group"
                foreach ($grupo in $subGrupos) {
                    $permisosTotales += ,@("/DENY $($grupo.name):'(WD,AD,WA,WEA,DE,DC,X)'")
                }

                crearCarpeta -ruta "$($raiz)$($linea.nivel1)\$($linea.nivel2)" -permisos $permisosTotales -nivel1 $linea.nivel1
            }
	    }
    
        #Comprueba que la OU de nivel 3 requerida existe y tiene carpeta, sino crea la OU y la carpeta
        if ($linea.nivel3) {
            if ($activeDirectory) {
                crearOU -nombre $linea.nivel3 -rutaOU "OU=$($linea.nivel2),OU=$($linea.nivel1),$($dc)" -descripcion $linea.nivel3_descripcion -ruta "$($raiz)$($linea.nivel1)\$($linea.nivel3)" -padre $linea.nivel2
            } else {
                crearCarpeta -ruta "$($raiz)$($linea.nivel1)\$($linea.nivel2)\$($linea.nivel3)" -permisos @("/GRANT $($linea.nivel3):'(GR,RD,RA,REA,WD,AD,WA,WEA,DE,DC,X)'") -nivel1 $linea.nivel1
            }
        } 

        #CREACIÓN DE USUARIOS
        if (-not $linea.nombre -and -not $linea.apellido1) { #Comprueba si es una línea que sirve para crear una OU y de ser así informa y omite
            Write-Host -ForegroundColor Yellow "No se creará ningún usuario en esta línea"
        } else { #En caso contrario, comprueba a que nivel pertenecerá el nuevo usuario
            
            #Crea el login del usuario a partir de la primer letra de su nombre y su primer apellido
            $login = ($($linea.nombre).substring(0,1)+$($linea.apellido1)).toLower()

            if ($activeDirectory) {
                if (-not $linea.nivel2 -and -not $linea.nivel3) { #Crea un usuario de nivel 1
                    crearUsuario -usuario $login -nivel $($linea.nivel1) -rutaOU "OU=$($linea.nivel1),$($dc)"
                } elseif (-not $linea.nivel3) { #Crea un usuario de nivel 2
                    crearUsuario -usuario $login -nivel $($linea.nivel2) -rutaOU "OU=$($linea.nivel2),OU=$($linea.nivel1),$($dc)"
                } else { #Crea un usuario de nivel 3
                    crearUsuario -usuario $login -nivel $($linea.nivel3) -rutaOU "OU=$($linea.nivel3),OU=$($linea.nivel2),OU=$($linea.nivel1),$($dc)"
                }
            } else {
                #Crea la carpeta del usuario y de su perfil móvil
                crearCarpeta -ruta "$($raiz)$($linea.nivel1)_USERS\$login" -permisos "/GRANT $($login):'(OI)(CI)(F,GR,RD,RA,REA)'" -nivel1 $linea.nivel1
                crearCarpeta -ruta "$($raiz)$($linea.nivel1)_PROFILES\$login" -permisos "/GRANT $($login):'(OI)(CI)(F,GR,RD,RA,REA)'" -nivel1 $linea.nivel1
                #crearCarpeta -ruta "$($raiz)$($linea.nivel1)_FOLDERS\$login" -permisos "/GRANT $($login):'(OI)(CI)(F,GR,RD,RA,REA)'" -nivel1 $linea.nivel1

                #Asigna al usuario una unidad de red mapeada a su carpeta particular y asigna la ruta a su perfil móvil
                Set-ADUser -Identity $login -HomeDirectory "\\$($env:computername)\$($linea.nivel1)_USERS$\$login" -HomeDrive "Z:" -ProfilePath "\\$($env:computername)\$($linea.nivel1)_PROFILES$\$login\$login"
            }
        }

        $fila++ #Incrementa el contador de la fila actual
    }
}

# Crea la estructura de unidades organizativas y los usuarios
iterarAchivo -activeDirectory "true"

# Crea la estructura de carpetas compartidas y asigna los permisos sobre el sistema de ficheros
iterarAchivo
