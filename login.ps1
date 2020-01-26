### CREAMOS UNA CARPETA tmp EN LA CARPETA PERSONAL DE CADA USUARIO (Z:) Y MAPEAMOS GOOGLE_COMPANY EN G: ###

$letterdrive = Get-SmbMapping | Where-Object {$_.LocalPath -like 'Z:'} | Select-Object LocalPath # => Z:

# Función para obtener un string aleatorio
function randomString() {
    return [System.Guid]::NewGuid().ToString()
}

# Comprueba si Z: existe
if ($letterdrive) {
    New-Item -Path "Z:\tmp" -ItemType Directory -Force
}

# Creamos 3 carpetas aleatorias dentro de Z:\tmp
for ($i=1; $i -le 3; $i++) {
    New-Item -Type Directory -Path "Z:\tmp\$(randomstring)" -Force
}

# Mapeamos la unidad G: con GOOGLE_COMPANY
if(Test-Path \\Serverws2016\google_company) {
    New-SmbMapping -LocalPath 'G:' -RemotePath '\\Serverws2016\google_company'
}