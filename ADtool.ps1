#######################################################################################################################################
#Skrypt w trakcie budowy, przykładowe dane do podmiany oznaczone są trzema hashami ###
#TODO:
# generator nazwy, usuwanie znaków- do funkcji
# odwołanie do aplikacji tworzącej skrzynkę mailową
################################################################################################################3











############################################################################################################################################################
                                                        #FUNKCJE
#######################################################################################################################################################

function passgen {#generowanie losowego hasła
    echo "generating random password"
    Write-Host
    Function MakeUp-String([Int]$Size = 8, [Char[]]$CharSets = "ULNS", [Char[]]$Exclude) {
        $Chars = @(); $TokenSet = @()
        If (!$TokenSets) {$Global:TokenSets = @{
            U = [Char[]]'ABCDEFGHIJKLMNOPQRSTUVWXYZ'                               
            L = [Char[]]'abcdefghijklmnopqrstuvwxyz'                                
            N = [Char[]]'0123456789'                                                
            S = [Char[]]'!"#$%&''()*+,-./:;<=>?@[\]^_`{|}~'                         
        }}
        $CharSets | ForEach {
            $Tokens = $TokenSets."$_" | ForEach {If ($Exclude -cNotContains $_) {$_}}
            If ($Tokens) {
                $TokensSet += $Tokens
                If ($_ -cle [Char]"Z") {$Chars += $Tokens | Get-Random}             #uppercase
            }
        }
        While ($Chars.Count -lt $Size) {$Chars += $TokensSet | Get-Random}
        ($Chars | Sort-Object {Get-Random}) -Join ""                                #Mix string
    }; Set-Alias Create-Password MakeUp-String -Description "Generate a random string (password)"
    $randompassword = MakeUp-string
    $rndpass = $randompassword | Out-String
    $pass = ConvertTo-SecureString -string $rndpass -AsPlainText -Force
    echo "password generated" 
    $global:pass = $pass
    $global:rndpass = $rndpass
    set-clipboard ($rndpass)

}

function checksam{ #sprawdzanie loginu po imieniu i nazwisku
    $fname = Read-Host("imię")
    $lname = Read-Host("nazwisko")
    $user = get-aduser -Filter {GivenName -eq $fname -and Surname -eq $lname} -Properties *
    $user = $user.SamAccountName
    $user 
}

function checkreportssam { #sprawdzanie podwładnych po imieniu i nazwisku lidera
    $fname = Read-Host("imię")
    $lname = Read-Host("nazwisko")
    $manager = get-aduser -Filter {GivenName -eq $fname -and Surname -eq $lname} -Properties *
    $manager = $manager.SamAccountName
    Write-Host "login dla $fname $lname"
    $manager
    $userslist = (Get-Aduser -Identity  $manager -Properties directreports | Select-Object -ExpandProperty directreports | Get-Aduser -Properties *  )
    $userslist = $userslist | Select-Object  samaccountname,title,description,city 
    out-host -inputobject $userslist
    #$global:manager = $manager
}

function checkifuserexist{param($tocheck) #sprawdzanie czy użytkownik istnieje
    if (@(Get-ADUser -Filter { SamAccountName -eq $tocheck }).Count -eq 0) {
        Write-Host  "User $tocheck does not exist."
    }
        else  {Write-Warning -Message "User $tocheck already exists" 
        } 
}


function proceed{         
    Read-Host ("Proceed? (CTRL-C to abort)") | Out-Null
}

function validator{ param ( $functiontorun) #walidator
    $exit = 1
    While ($exit -eq 1){        
        invoke-expression $functiontorun
        $yn = read-host("proceed? y/n")
        if ($yn -eq "y") {
            $exit = 0
        }
    }
}




#################################################################################################################################################################
                                        #INTRO
################################################################################################################################################################

$count = 0 
while ($count -ne 1){#d dowyrzucenia, c do zintegrowania z e
echo "Co chcesz zrobić:
a) wyłączyć konto 
b) zmienić datę wygaśnięcia konta
c) utworzyć nowe konto (full manual)
d) utworzyć nowe konto (manual + kopiowanie grup i OU ze wskazanego użytkownika)
e) utworzyć nowe konto (full auto) 
f) skopiować grupy
g) password generator
h) sprawdzić login po nazwisku
i) sprawdzić podwładnych użytkownika
q) zakończyć pracę"
$choice = read-host("wybierz")


#################################################################################################################################################################
                                            #DISABLE ACCOUNT
################################################################################################################################################################

if ($choice -eq 'a'){#wyłączenie konta
    Remove-Variable * -ErrorAction SilentlyContinue
    $name = read-host ("nazwa użytkownika do wyłączenia")
    $user = get-aduser $name -properties *

    #===========Remove GROUPS
    ForEach($group in $user.MemberOf){
        Remove-ADGroupMember -Identity $group -Members $user.SamAccountName -Confirm:$false 
        }
    #=============CHANGE OU

    $disabledou = "OU=__DISABLED__ACCOUNTS__,DC=domena,DC=dom"  ###przykładowa domena
    Set-ADUser $user.samaccountname -ProfilePath $disabledou -Manager $null #remove manager 
    Move-ADObject -identity $user.DistinguishedName -TargetPath $disabledou

    #=============DISABLE ACCOUNT
    Disable-ADAccount -Identity $user.SamAccountName 
    set-clipboard "Konto $name zostało wyłączone."
    
}

#################################################################################################################################################################
                                                        #CHANGE EXPIRATION DATE
#################################################################################################################################################################


elseif ($choice -eq 'b') {
    $name = read-host ("nazwa użytkownika")
    $expdate = read-host ("expiration date")
    Set-ADUser $name -AccountExpirationDate $expdate
    set-clipboard "konto w domenie zostało przedłużone do $expdate"
}


###################################################################################################################################################################
                                        #utworzyć nowe konto (full manual)
##################################################################################################################################################################


elseif ($choice -eq 'c') {
    


    Remove-Variable * -ErrorAction SilentlyContinue
    #==============================================passgen call
    passgen

    #=============================================COLLECT DATA=========================================================================================================
    echo "collecting data"


    $manager = read-Host ("manager")
    $office = read-host ("biuro")
    $title = read-host ("stanowisko")
    $ErrorActionPreference = "silentlycontinue" 
    $copy_from = read-host("podaj użytkownika do skopiowania grup(opcjonalne)")
    $olduser = get-aduser $copy_from -Properties *
    $ErrorActionPreference = 1
    $newuserfirstname = read-host ("First Name") 
    $newuserlastname = read-host ("Last Name")
    $expdate = read-host ("Expiration Date dd.mm.rrrr")
    $department = Read-Host ('departament')
    $company = read-host ('spółka')
    $city = read-host ('miasto')
    $count = 1
    ####################################OU HASHTABLES###############
    while ($count -eq 1 ){
        $Ifhq = Read-Host (
            "
            (h)HQ
            (i)IT 
            (t)teren?")
        If ($Ifhq -eq 'h'){ #ustalanie OU dla HQ
            echo "
            acc = Accounting
            adm = Administracja
            cc = Contact Center
            dst = Dostawcy
            dut = DUT
            dyr = Dyrektorzy
            fin =Finansowy
            fzw = Firmy zewnetrzne
            glc = Glencross
            inw = Inwestycje
            kier = Kierownicy
            log = Logistyka
            noc = NOC
            och = Ochrona
            oin = Ochrona Informacji Niejawnych
            pr = Prawnicy
            r = Recepcja
            se = Sekretariat
            sgt = SGT
            spe = Special
            spr = Sprzedaż
            sun = Suntech Adm
            tec = Technika
            zak = Zakupy
            zp = Zarządzanie Projektami
            "#mozliwe wybory



            $hqou = 'OU=Users,OU=SKYNET GDYNIA,DC=domena,DC=dom' #hashtable dla hq ###przykładowe dane domeny
            $hq = @{
                acc = "OU=Accounting,$hqou";
                adm = "OU=Administracja,$hqou";
                cc = "OU=Contact Center,$hqou";
                dst = "OU=Dostawcy,$hqou";
                dut = "OU=DUT,$hqou";
                dyr = "OU=Dyrektorzy,$hqou";
                fin = "OU=Finansowy,$hqou";
                fzw = "OU=Firmy zewnetrzne,$hqou";
                glc = "OU=Glencross,$hqou";
                inw = "OU=Inwestycje,$hqou";
                kier = "OU=Kierownicy,$hqou";
                log = "OU=Logistyka,$hqou";
                noc = "OU=NOC,$hqou";
                och = "OU=Ochrona,$hqou";
                oin = "OU=Ochrona Informacji Niejawnych,$hqou";
                pr = "OU=Prawnicy,$hqou";
                r = "OU=Recepcja,$hqou";
                se = "OU=Sekretariat,$hqou";
                sgt = "OU=SGT,$hqou";
                spe = "OU=Special,$hqou";
                spr = "OU=Sprzedaż,$hqou";
                sun = "OU=Suntech Adm,$hqou";
                tec = "OU=Technika,$hqou";
                zak = "OU=Zakupy,$hqou";
                zp = "OU=Zarządzanie Projektami,$hqou";
            }                                                       ###OU wg struktury firmy
            $foo = 1 #ou builder
            while ($foo -eq 1){
                $in = read-host(' deklaracja OU')
                $OU = $hq[$in]
                $bar = 1
                while ($bar -eq 1){ #weryfikator OU
                    $OU
                    $zgoda = read-host('czy powyżej widnieje prawidłowa ścieżka OU? t/n')
                    if ($zgoda -eq 't'){
                        $foo = 0 
                        $bar = 0
                        $count = 0
                    }
                    elseif ($zgoda -eq 'n'){
                    'wprowadź OU ponownie'
                    $bar = 0 
                    }
                    else {'błędna odpowiedź: t/n'}
                    }
                    }
                } 

        ############################################################################IT
        If ($Ifhq -eq 'i'){ #ustalanie OU dla IT
            echo "
            ad = DIIT
            b = BILLING
            drab = DRAB
            drus2 = DRUS UTRZYMANIE
            drus1 = DRUS I linia
            dwi = DWI
            "#mozliwe wybory

            $itou = "OU=SKYNET_IT ,DC=domena,DC=dom" #hashtable dla it ###przykładowe dane
            $dusitou = "OU=IT_DUSIT,OU=SKYNET_IT,DC=domena,DC=dom"#hashtable dla dusit ###przykładowe dane
            $it = @{
                ad = "OU=GDYNIA_AD,$itou"
                b = "OU=Gynia_Bill,$itou"
                drab = "OU=Gdynia_DRAB,$itou"
                drus2 = "OU=DRUS_UTRZYMANIE,$dusitou"
                drus1 = "OU=IT_DUSIT_1L,$dusitou"
                dwi = "OU=DWI,$dusitou"
            }

            $foo = 1 #ou builder
            while ($foo -eq 1){
                $in = read-host(' deklaracja OU')
                $OU = $it[$in]
                $bar = 1
                while ($bar -eq 1){ #weryfikator OU
                    $OU
                    $zgoda = read-host('czy powyżej widnieje prawidłowa ścieżka OU? t/n')
                    if ($zgoda -eq 't'){
                        $foo = 0 
                        $bar = 0
                        $count = 0
                    }
                    elseif ($zgoda -eq 'n'){
                    'wprowadź OU ponownie'
                    $bar = 0 
                    }
                    else {'błędna odpowiedź: t/n'}
                    }
                    }
                } 
        
        #############################################################TEREN
        if ($ifhq -eq 't'){#ustalanie OU dla terenu
            get-adorganizationalunit -LDAPFilter '(name=*)' -SearchBase 'OU=ZAKLADY,DC=domena,DC=dom' -SearchScope OneLevel | Format-Table Name ###przykładowe dane
            #listuje wszystkie OU dla terenu
            $terenou = 'OU=ZAKLADY,DC=domena,DC=dom'
            $begining = 'OU='
            $foo = 1 #ou builder
            while ($foo -eq 1){
                $miasto = Read-Host('miasto')
                $OU = "OU=Users,$begining$miasto,$terenou"
                $bar = 1
                while ($bar -eq 1){ #weryfikator OU
                    $OU
                    $zgoda = read-host('czy powyżej widnieje prawidłowa ścieżka OU? t/n')
                    if ($zgoda -eq 't'){
                        $foo = 0 
                        $bar = 0
                        $count = 0
                    }
                    elseif ($zgoda -eq 'n'){
                    'wprowadź OU ponownie'
                    $bar = 0 
                    }
                    else {'błędna odpowiedź: t/n'}
                    }
                    }
        
        
        }
    }







    echo "creating username"
    $name = "$newuserlastname $newuserfirstname" #create username

    $samaccountname1 = "$($newuserfirstname[0])$newuserlastname" #create samaccountname
    $samaccountname = $samaccountname1 -replace "Ą","a" -replace "ć","c" -replace "ę","e" -replace "ł","l" -replace "ń","n" -replace "ó","o" -replace "ś","s" -replace "ź","z" -replace "ż","z"#usuwanie polskich znaków
    $samaccountname = $samaccountname.ToLower()

    echo "getting OU information"
    $ErrorActionPreference = "silentlycontinue" 
    $user = Get-ADUser -Identity $copy_from -Properties CanonicalName 
    $oldou = ($user.DistinguishedName -split ",",2)[1] #get OU
    $ErrorActionPreference = 1


    #===============================================CHECK IF USER EXISTS==========================================

    echo "checking if user exists"
    if (@(Get-ADUser -Filter { SamAccountName -eq $SamAccountName }).Count -eq 0) {
        Write-Host  "User $SamAccountName does not exist."
    }
        else  {Write-Warning -Message "User $SamAccountName already exists" 
            } 
    Read-Host ("Proceed? (CTRL-C to abort)") | Out-Null




    #===============================================NEW USER=========================================================

    echo "creating user"
    $params =@{ 
        
        "AccountExpirationDate" = $expdate
        "SamAccountName" =  $samaccountname
        "Department" = $department
        "AccountPassword" =  $pass
        "ChangePasswordAtLogon" = 1
        "city" = $city
        "Company" = $company
        "DisplayName" = $name 
        "Enabled" = 1
        "GivenName" = $newuserfirstname
        "Manager" = $manager
        "Name" = $name
        "Office" =$office
        "PasswordNeverExpires" = 0
        "ScriptPath" = 'logon.vbs'
        "surname" = $newuserlastname
        "title"  = $title
        "path" = $OU
    }

    New-ADUser @params
    $ErrorActionPreference = "silentlycontinue" #bypass- office replacement throws error
    Set-ADUser -Identity $samaccountname -UserPrincipalName $samaccountname@domena.dom
    $newuser = get-aduser $samaccountname -Properties *

    #============EDIT OTHER PARAMS
    echo "editing extra parameters"
    Set-Aduser -Identity $samaccountname -Replace @{description=$newuser.Title}
    Set-Aduser -Identity $samaccountname -Replace @{office=$office} 

    $ErrorActionPreference = 1 #bypass off (office replacement)

    #===========COPY GROUPS
    echo "copying groups"
    ForEach($group in $olduser.MemberOf){
        Add-ADGroupMember -Identity $group -Members $newuser.SamAccountName
    }


    #========================================================HOME FOLDER
    cd "c:\configs"
    $samaccountstring = $samaccountname | out-string
    start-process mkhome.exe -ArgumentList $samaccountstring #odwołanie do aplikacji zewnętrznej


    Set-Clipboard ($samaccountstring)
    read-host("Press enter to copy client info to a clipboard, CTRL-C to abort")
    #=========================================================Clipboard INFO
    $toclipboard = "Konto w domenie zostało założone.
    Login : $samaccountname

    Pierwsze logowanie:
                - przełożony zmienia hasło użytkownikowi na stronie https://manager.skynet.xx/ (logowanie domenowe). 
        - najpierw logowanie do domeny
        - potem zmiana hasła na znane tylko użytkownikowi
        - po udanej zmianie hasła można się logować do poczty"
    Set-Clipboard ($toclipboard) ###informacja dla użytkownika, do podmienienia

    }

####################################################################################################################################################################
                                                #utworzyć nowe konto (manual + groups auto copy)    
###################################################################################################################################################################


elseif ($choice -eq 'd') {
    
    Remove-Variable * -ErrorAction SilentlyContinue
   #==============================================passgen call
   passgen
    #=============================================COLLECT DATA=========================================================================================================
    echo "collecting data"

    

    $manager = read-Host ("manager")
    #copy properties from first direct report of manager:
    $copy_from = read-host ("użytkownik do skopiowania")
    $office = read-host ("biuro")
    $title = read-host ("stanowisko")
    $olduser = get-aduser $copy_from -Properties *
    $newuserfirstname = read-host ("First Name") 
    $newuserlastname = read-host ("Last Name")
    $expdate = read-host ("Expiration Date dd.mm.rrrr")





    echo "creating username"
    $name = "$newuserlastname $newuserfirstname" #create username

    $samaccountname1 = "$($newuserfirstname[0])$newuserlastname" #create samaccountname
    $samaccountname = $samaccountname1 -replace "ą","a" -replace "ć","c" -replace "ę","e" -replace "ł‚","l" -replace "ń","n" -replace "ó","o" -replace "ś","s" -replace "ż","z" -replace "ź","z"
    $samaccountname = $samaccountname.ToLower()

    echo "getting OU information"
    $user = Get-ADUser -Identity $copy_from -Properties CanonicalName 
    $oldou = ($user.DistinguishedName -split ",",2)[1] #get OU


    #===============================================CHECK IF USER EXISTS==========================================

    echo "checking if user exists"
    if (@(Get-ADUser -Filter { SamAccountName -eq $SamAccountName }).Count -eq 0) {
        Write-Host  "User $SamAccountName does not exist."
    }
        else  {Write-Warning -Message "User $SamAccountName already exists" 
            } 
    Read-Host ("Proceed? (CTRL-C to abort)") | Out-Null #todo: odwołanie do funkcji




    #===============================================NEW USER=========================================================

    echo "creating user"
    $params =@{ 
        
        "AccountExpirationDate" = $expdate
        "SamAccountName" =  $samaccountname
        "Department" = $olduser.department
        "AccountPassword" =  $pass
        "ChangePasswordAtLogon" = 1
        "city" = $olduser.city
        "Company" = $olduser.company
        "DisplayName" = $name 
        "Enabled" = 1
        "GivenName" = $newuserfirstname
        "Manager" = $manager
        "Name" = $name
        "Office" =$office
        "PasswordNeverExpires" = 0
        "ScriptPath" = $olduser.scriptpath
        "StreetAddress" = $olduser.streetaddress
        "surname" = $newuserlastname
        "title"  = $title
        "path" = $oldou
    }

    New-ADUser @params
    $ErrorActionPreference = "silentlycontinue" #bypass- office replacement throws error
    Set-ADUser -Identity $samaccountname -UserPrincipalName $samaccountname@domena.dom
    $newuser = get-aduser $samaccountname -Properties *

    #============EDIT OTHER PARAMS
    echo "editing extra parameters"
    Set-Aduser -Identity $samaccountname -Replace @{description=$newuser.Title}
    Set-Aduser -Identity $samaccountname -Replace @{office=$office} 

    $ErrorActionPreference = 1 #bypass off (office replacement)

    #===========COPY GROUPS
    echo "copying groups"
    ForEach($group in $olduser.MemberOf){
        Add-ADGroupMember -Identity $group -Members $newuser.SamAccountName
    }


    #========================================================HOME FOLDER
    cd "c:\configs"
    $samaccountstring = $samaccountname | out-string
    start-process mkhome.exe -ArgumentList $samaccountstring


    Set-Clipboard ($samaccountstring)
    read-host("Press enter to copy client info to a clipboard, CTRL-C to abort")
    #=========================================================Clipboard INFO
    $toclipboard = "Konto w domenie zostało założone.
    Login : $samaccountname

    Pierwsze logowanie:
                - przełożony zmienia hasło użytkownikowi na stronie https://manager.skynet.xx/ (logowanie domenowe). 
        - najpierw logowanie do domeny
        - potem zmiana hasła na znane tylko użytkownikowi
        - po udanej zmianie hasła można się logować do poczty"
    Set-Clipboard ($toclipboard)

}


######################################################################################################################################################################
                                                                    #NOWE KONTO FULL AUTO
####################################################################################################################################################################


elseif ($choice -eq 'e') {####################WYBÓR
  


   # Remove-Variable * -ErrorAction SilentlyContinue
    #==============================================passgen call
    passgen

    #=============================================COLLECT DATA=========================================================================================================
    echo "collecting data"
    echo "Manager:"
    checkreportssam
    
    
    $agreement = 0
    while ($agreement -eq 0){
        $copy_from = read-host("podaj nazwę użytkownika do skopiowania")
        $tn = read-host("czy nazwa $copy_from jest poprawna? t/n")
        if ($tn -eq "t"){
            $agreement = 1
        }
    }
    $olduser = get-aduser $copy_from -Properties *
    $newuserfirstname = read-host ("First Name") 
    $newuserlastname = read-host ("Last Name")
    $expdate = read-host ("Expiration Date dd.mm.rrrr")





    echo "creating username"
    $name = "$newuserlastname $newuserfirstname" #create username

    $samaccountname1 = "$($newuserfirstname[0])$newuserlastname" #create samaccountname
    $samaccountname = $samaccountname1 -replace "Ą","a" -replace "ć","c" -replace "ę","e" -replace "ł","l" -replace "ń","n" -replace "ó","o" -replace "ś","s" -replace "ź","z" -replace "ż","z"
    $samaccountname = $samaccountname.ToLower()

    echo "getting OU information"
    $user = Get-ADUser -Identity $copy_from -Properties CanonicalName 
    $oldou = ($user.DistinguishedName -split ",",2)[1] #get OU


    #===============================================CHECK IF USER EXISTS==========================================

    echo "checking if user exists"
    if (@(Get-ADUser -Filter { SamAccountName -eq $SamAccountName }).Count -eq 0) {
        Write-Host  "User $SamAccountName does not exist."
    }
        else  {Write-Warning -Message "User $SamAccountName already exists" 
            } 
    Read-Host ("Proceed? (CTRL-C to abort)") | Out-Null




    #===============================================NEW USER=========================================================

    echo "creating user"
    $params =@{ 
        "AccountExpirationDate" = $expdate
        "SamAccountName" =  $samaccountname
        "Department" = $olduser.department
        "AccountPassword" =  $pass
        "ChangePasswordAtLogon" = 1
        "city" = $olduser.city
        "Company" = $olduser.company
        "DisplayName" = $name 
        "Enabled" = 1
        "GivenName" = $newuserfirstname
        "Manager" = $manager
        "Name" = $name
        "Office" =$olduser.office
        "PasswordNeverExpires" = 0
        "ScriptPath" = $olduser.scriptpath
        "StreetAddress" = $olduser.streetaddress
        "surname" = $newuserlastname
        "title"  = $olduser.title
        "path" = $oldou
    }

    New-ADUser @params
    $ErrorActionPreference = "silentlycontinue" #bypass- office replacement throws error
    Set-ADUser -Identity $samaccountname -UserPrincipalName $samaccountname@domena.dom
    $newuser = get-aduser $samaccountname -Properties *

    #============EDIT OTHER PARAMS
    echo "editing extra parameters"
    Set-Aduser -Identity $samaccountname -Replace @{description=$newuser.Title}
    Set-Aduser -Identity $samaccountname -Replace @{office=$olduser.office} 

    $ErrorActionPreference = 1 #bypass off (office replacement)

    #===========COPY GROUPS
    echo "copying groups"
    ForEach($group in $olduser.MemberOf){
        Add-ADGroupMember -Identity $group -Members $newuser.SamAccountName
    }


    #========================================================HOME FOLDER
    cd "c:\configs"
    $samaccountstring = $samaccountname | out-string
    start-process mkhome.exe -ArgumentList $samaccountstring


    Set-Clipboard ($samaccountstring)
    read-host("Press enter to copy client info to a clipboard, CTRL-C to abort")
    #=========================================================Clipboard INFO
    $toclipboard = "Konto w domenie zostało założone.
    Login : $samaccountname

    Pierwsze logowanie:
                - przełożony zmienia hasło użytkownikowi na stronie https://manager.skynet.xx/ (logowanie domenowe). 
        - najpierw logowanie do domeny
        - potem zmiana hasła na znane tylko użytkownikowi
        - po udanej zmianie hasła można się logować do poczty"
    Set-Clipboard ($toclipboard)
    }




#####################################################################################################################
                                                #KOPIOWANIE GRUPY
#####################################################################################################################                                                
elseif ($choice -eq 'f') {
    $ErrorActionPreference = "silentlycontinue"
    $copyfrom = Read-Host("użytkownik wzorcowy")
    $copyto = read-host("nowy użytkownik")

    $olduser = get-aduser $copyfrom -Properties *
    $newuser = get-aduser $copyto -Properties *

    echo "copying groups"
    ForEach($group in $olduser.MemberOf){
        Add-ADGroupMember -Identity $group -Members $newuser.SamAccountName
        }
    }


######################################################################################################################
                                            #PASSGEN CALL
######################################################################################################################


elseif ($choice -eq 'g') {
    passgen
    $rndpass 
    set-clipboard ($rndpass) ###tostring?
}


############################################################################################################################################
#WERYFIKATORY
############################################################################################################################################


elseif ($choice -eq 'h') {checksam}

elseif ($choice -eq 'i'){checkreportssam}



##################################################################################################################################################
                                                    #Formuły

                                            







#####################################QUIT#####################################################


elseif ($choice -eq 'q') {$count = 1}

else {"błędny wybór"} #wybór z poza zakresu powrót na początek pętli
}