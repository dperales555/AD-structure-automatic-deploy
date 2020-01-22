$confirmation = Read-Host "¿Seguro que quieres proceder? [y]:"
if ($confirmation -eq 'y') {
    #Eliminar OUs
    Write-Host "Eliminando OUs"
    Remove-ADOrganizationalUnit -Identity "OU=  GOOGLE,DC=OLIMPO,DC=ASIX" -Recursive -Confirm:$False
    Write-Host -ForegroundColor Green "¡OUs eliminadas correctamente!"

    #Eliminar shares
    Write-Host "Eliminando shares"
    Remove-SmbShare -Name "GOOGLE_COMPANY" -Force -Confirm:$False
    Remove-SmbShare -Name "GOOGLE_USERS$" -Force -Confirm:$False
    Remove-SmbShare -Name "GOOGLE_PROFILES$" -Force -Confirm:$False
    Write-Host -ForegroundColor Green "¡Shares eliminados correctamente!"

    #Eliminar carpetas
    Write-Host "Eliminando carpetas"
    Remove-Item -Recurse "C:\GOOGLE" -Force -Confirm:$False
    Remove-Item -Recurse "C:\GOOGLE_USERS" -Force -Confirm:$False
    Remove-Item -Recurse "C:\GOOGLE_PROFILES" -Force -Confirm:$False
    Write-Host -ForegroundColor Green "¡Carpetas eliminadas correctamente!"
} else {
    Write-Host -ForegroundColor Yellow "¡Operación abortada!"
}