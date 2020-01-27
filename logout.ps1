### ELIMINAMOS TODO EL CONTENIDO DE LA CARPETA Z:\tmp DE CADA USUARIO AL CERRAR SESIÓN ###

# Comprueba si Z: existe
if (Get-SmbMapping | Where-Object {$_.LocalPath -like 'Z:'}) {
    Remove-Item Z:\tmp\* -Recurse -Force
}