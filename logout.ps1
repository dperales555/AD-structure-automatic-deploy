# Comprueba si Z: existe
if (Get-SmbMapping | Where-Object {$_.LocalPath -like 'Z:'}) {
    #Si existse, borra todo elcontenido de la carpeta "tmp"
    Remove-Item Z:\tmp\* -Recurse -Force
}