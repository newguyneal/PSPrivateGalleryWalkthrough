function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

        [Switch]$KeepConnectionOpen
	)

    # Default value
    $Ensure = 'Absent'
    
    # Create sql connection object
    $script:sqlConnection = New-mySqlConnection -InstanceName $InstanceName

    # Check if database is present
    $commandResult = Invoke-mySqlCommand -Connection $sqlConnection -CommandText "SELECT name FROM [master].[sys].[databases] WHERE name = '$Name'" -CommandType Scalar

    if ($commandResult -eq $Name){$Ensure = 'Present'}

    # Close the sql connection  
    if(-not $KeepConnectionOpen){Remove-mySqlConnection -Connection $sqlConnection}

    @{
	    InstanceName = $InstanceName
	    Name = $Name
	    Ensure = $Ensure
    }
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = 'Present'
	)

    $currentState = Get-TargetResource -InstanceName $InstanceName -Name $Name -KeepConnectionOpen

    # Database is absent and it should have been present
    if($Ensure -eq 'Present')
    {
        Invoke-mySqlCommand -Connection $Script:sqlConnection -CommandText "CREATE DATABASE [$Name]" -CommandType NonQuery

        # Set AUTO_CLOSE to OFF to workaround Recovery Pending issue.
        Invoke-mySqlCommand -Connection $Script:sqlConnection -CommandText "ALTER DATABASE [$Name] SET AUTO_CLOSE OFF" -CommandType NonQuery
    }

    # Database is present and it should have been absent
    else
    {
        Invoke-mySqlCommand -Connection $Script:sqlConnection -CommandText "DROP DATABASE [$Name]" -CommandType NonQuery
    }

    # Close the sql connection    
    Remove-mySqlConnection -Connection $Script:sqlConnection
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = 'Present'
	)

    $currentState = Get-TargetResource -InstanceName $InstanceName -Name $Name

    # If not, then create it.
    if ($currentState.Ensure -ne $Ensure){return $false}
    else{return $true}
}

#region Helper functions
function New-mySqlConnection
{
    param
    (
        [Parameter(Mandatory)]
        $InstanceName
    )

    Write-Verbose -Message "Connecting to SQL instance (LocalDB)\$InstanceName ..."

    # Create sql connection object
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = "Server=(LocalDB)\$InstanceName;Integrated Security=True"
    $connection.Open()
    $connection
}

function Remove-mySqlConnection
{
    param
    (
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection
    )
    if($Connection.State -ne [System.Data.ConnectionState]::Closed){
        Write-Verbose -Message "Closing connection to SQL instance $($Connection.DataSource) ..."
        $Connection.Close()
    }
}

function Invoke-mySqlCommand
{
    param
    (
        [Parameter(Mandatory)]
        [System.Data.SqlClient.SqlConnection]$Connection,

        [Parameter(Mandatory)]
        [String]$CommandText,

        [ValidateSet('Scalar','NonQuery')]
        [String]$CommandType = 'NonQuery'
    )

    # Create sql command
    $Command = $Connection.CreateCommand()

    # Set the command text and execute it
    $Command.CommandText = $CommandText

    switch ($CommandType)
    {
        'Scalar' {$Command.ExecuteScalar()}
        'NonQuery' {$Command.ExecuteNonQuery()}        
    }
}

#endregion

Export-ModuleMember -Function *-TargetResource