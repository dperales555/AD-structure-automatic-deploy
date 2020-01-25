$letterdrive = Get-SmbMapping | Select-Object LocalPath # => Z:

# Función para obtener un string aleatorio
function randomString() {
    return [System.Guid]::NewGuid().ToString()
}

# Comprueba si Z: existe
if ($letterdrive) {
    New-Item -Path "$letterdrive\tmp" -ItemType Directory -Force
}

# Creamos 3 carpetas aleatorias dentro de Z:\tmp
for ($i=1; $i -le 3; $i++) {
    New-Item -Type Directory -Path "$letterdrive\tmp\$(randomstring)" -Force
}

# Mapeamos la unidad G: con GOOGLE_COMPANY
if(Test-Path \\Serverws2016\google_company) {
    New-SmbMapping -LocalPath 'G:' -RemotePath '\\Serverws2016\google_company'
}