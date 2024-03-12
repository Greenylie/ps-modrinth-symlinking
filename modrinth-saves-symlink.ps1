$modrinthProfilesPath = $env:APPDATA + "\com.modrinth.theseus\profiles"
$symlinkPath = "-"

#If modrinth is not installed in the standard directory
while (!(Test-Path -Path $modrinthProfilesPath)) {
    $modrinthPath = Read-Host "Please input Modrinth installation folder"
    $modrinthProfilesPath = $modrinthPath + "\profiles"
}

while (!(Test-Path -Path $symlinkPath)) {
    $symlinkPath = Read-Host "Please input symlink location folder"
}

# Gather modrinth profiles
$profiles = Get-ChildItem -Path $modrinthProfilesPath -Directory | Select-Object Name

$choosing = $true

while ($choosing) {
    Clear-Host
    
    Write-Host "Available profiles in ->" + $modrinthProfilesPath
    $i = 1
    foreach ($p in $profiles) {
        Write-Host "$i. $($p.Name)"
        $i++
    }

    $choice = Read-Host "Select which number's saves & backups would you like to symlink"

    if ($choice -ge 1 -and $choice -le $profiles.Count) {
        $profile = $profiles[$choice - 1].Name
        $choosing = $false
    } else {
        Write-Host "Please select a profile between 1 and $($profiles.Count)"
        Read-Host "\n Press any key to continue..."
    }

}

$profilePath = $modrinthProfilesPath + "\" + $profile

#Backup folder handling
if (Test-Path ($profilePath + "\backups") -PathType Container) {

    $files = Get-ChildItem ($profilePath + "\backups")

    if ($files.Count -gt 0) {
        # Set up the progress bar
        $totalFiles = $files.Count
        $progressParams = @{
            Activity = "Moving Files"
            Status = "Initializing..."
            PercentComplete = 0
        }

        do {
            $backupsDirName = Read-Host "Inserisci un nickname per la cartella backups"
            $backupsDirName = "backups_" + $backupsDirName
        } while (Test-Path -Path $backupsDirName)

        New-Item -ItemType Directory -Force -Path ($symlinkPath + "\" + $backupsDirName)

        Write-Progress @progressParams

        $counter = 0
        foreach ($file in $files) {
            Move-Item $file.FullName -Destination ($symlinkPath + "\" + $backupsDirName)  -Force
            $counter++
            $progressParams.PercentComplete = ($counter / $totalFiles) * 100
            $progressParams.Status = "Moving file $($file.Name)"
            Write-Progress @progressParams
        }

        Write-Host "Move operation complete."
    } else {
        Write-Host "There are no backups yet."
    }
}

Write-Host ("Making backups symlink -> " + $symlinkPath + "\" + $backupsDirName)
New-Item -ItemType Junction -Path ($profilePath + "\backups") -Target ($symlinkPath + "\" + $backupsDirName)

if (!(Test-Path -Path ($symlinkPath + "\saves\"))) { New-Item -ItemType Directory -Force -Path ($symlinkPath + "\saves\")}

do {
    $saves = Get-ChildItem ($profilePath + "\saves")
    Write-Host $saves.Count
    if ($saves.Count -le 0) { break }

    Write-Host "Found existing worlds."
    $nonSymLinks = @()
    foreach ($save in $saves) {
        $attributes = (Get-Item $save.FullName).Attributes
        if (!($attributes -band [System.IO.FileAttributes]::ReparsePoint)) { $nonSymLinks += $save }
    }

    if ($nonSymLinks.Count -le 0) { 
        Write-Host "All saves are already symlinked"
        break
    }

    $choosing = $true

    while ($choosing) {
        Clear-Host
        
        Write-Host "Available saves to symlink: "
        $i = 1
        foreach ($nonSymLink in $nonSymLinks) {
            Write-Host "$i. $($nonSymLink.Name)"
            $i++
        }
    
        $choice = Read-Host "Select which save you want to symlink or press 0 to skip"
    
        if ($choice -eq 0) {
            break
        }
        elseif ($choice -ge 1 -and $choice -le $nonSymLinks.Count) {
            $saveToSym = $nonSymLinks[$choice - 1].Name
            $nonSymLinks = $nonSymLinks | Where-Object { $_ -ne $nonSymLink }
            $choosing = $false

            $progressParams = @{
            Activity = "Moving Folder"
            Status = ("Moving folder" + $profilePath + "\saves\" + $saveToSym) 
            PercentComplete = 0
            }

            Write-Progress @progressParams

            Move-Item ($profilePath + "\saves\" + $saveToSym) -Destination ($symlinkPath + "\saves\") -Force

            $progressParams.PercentComplete = 100
            Write-Progress @progressParams

            Write-Host "Moved save folder" 
            New-Item -ItemType Junction -Path ($profilePath + "\saves\" + $saveToSym) -Target ($symlinkPath + "\saves\" + $saveToSym)
            Write-Host ("Created a symlink (junction) between:`n" + $symlinkPath + "\saves\" + $saveToSym + "<===>" + $profilePath + "\saves\" + $saveToSym)

        } else {
            Write-Host "Please select a save between 1 and $($profiles.Count). Or use 0 to skip"
            Read-Host "\n Press any key to continue..."
        }
    
    }
} while ($nonSymLinks.Count -ge 1)

do {
    $saves = Get-ChildItem ($profilePath + "\saves")
    $symLinkedSaves = Get-ChildItem ($symlinkPath + "\saves")
    $symLinksNotSaves = $symLinkedSaves | Where-Object { $_.Name -notin $saves.Name }

    if ($symLinksNotSaves.Count -eq 0) { break }

    $choosing = $true

    while ($choosing) {
        Clear-Host
        
        Write-Host "Available symlinks to link in the saves folder: "
        $i = 1
        foreach ($symLinkNotSave in $symLinksNotSaves) {
            Write-Host "$i. $($symLinkNotSave.Name)"
            $i++
        }
    
        $choice = Read-Host "Select which symlink you want to link or press 0 to skip"
    
        if ($choice -eq 0) {
            break
        }
        elseif ($choice -ge 1 -and $choice -le $symLinksNotSaves.Count) {
            $symLinkToSave = $symLinksNotSaves[$choice - 1].Name
            $symLinksNotSaves = $symLinksNotSaves | Where-Object { $_ -ne $symLinkToSave }
            $choosing = $false

            New-Item -ItemType Junction -Path ($profilePath + "\saves\" + $symLinkToSave) -Target ($symlinkPath + "\saves\" + $symLinkToSave)
            Write-Host ("Created a symlink (junction) between:`n" + $profilePath + "\saves\" + $symLinkToSave + "<===>" + $symlinkPath + "\saves\" + $symLinkToSave)

        } else {
            Write-Host "Please select a symlink between 1 and $($profiles.Count). Or use 0 to skip"
            Read-Host "\n Press any key to continue..."
        }
    }
} while ($symLinksNotSaves.Count -ge 1)
