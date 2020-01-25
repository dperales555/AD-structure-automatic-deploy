### ELIMINAMOS TODO EL CONTENIDO DE LA CARPETA Z:\tmp DE CADA USUARIO AL CERRAR SESIÓN ###

$letterdrive = Get-SmbMapping | Where-Object {$_.LocalPath -like 'Z:'} | Select-Object LocalPath # => Z:

# Comprueba si Z: existe
if ($letterdrive) {
    Remove-Item Z:\tmp\* -Recurse -Force
}