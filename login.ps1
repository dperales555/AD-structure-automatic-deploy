###CREAMOS UNA CARPETA tmp EN LA CARPETA PERSONAL DE CADA USUARIO (Z:) Y MAPEAMOS GOOGLE_COMPANY EN G: ###

#Comprobamos si el equipo forma parte de un dominio
if ((Get-WmiObject Win32_ComputerSystem).PartOfDomain) {

    #Comprueba si Z: existe
    if (Get-SmbMapping | Where-Object {$_.LocalPath -eq "Z:"}) {
        #Creamos la carpeta "tmp"
        New-Item -Path "Z:\tmp" -ItemType Directory -Force

        #Función para obtener un string aleatorio
        function stringAleatorio() {
            return [System.Guid]::NewGuid().ToString()
        }

        #Creamos 3 carpetas aleatorias en "Z:\tmp\"
        for ($i=1; $i -le 3; $i++) {
            New-Item -Type Directory -Path "Z:\tmp\$(stringAleatorio)" -Force
        }
    }

    #Almacenamos el FQDN del controlador de dominio
    $fqdn = (Get-WmiObject Win32_ComputerSystem).Domain

    #Obtenemos la IP del controlador del dominio
    $ip = [System.Net.Dns]::GetHostByName($fqdn).AddressList.IPAddressToString | Select-Object -first 1
    
    #Resolvemos el nombre de host del controlador del dominio
    $hostname = (Resolve-DnsName -Name $ip).NameHost

    #Comprobamos si el recurso acabado en "_COMPANY" es accesible
    if(Test-Path "\\$hostname\GOOGLE_COMPANY") { #FALTA CAMBIAR "GOOGLE" POR *
        #Mapeamos la unidad G: con el recurso compartido "GOOGLE_COMPANY"
        New-SmbMapping -LocalPath "G:" -RemotePath "\\$($hostname)\GOOGLE_COMPANY" #FALTA CAMBIAR "GOOGLE" POR *
    }
}
