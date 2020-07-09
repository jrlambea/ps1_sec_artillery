[CmdletBinding()]
param (
    # S3 Bucket to target
    [Parameter()]
    [String]
    $Bucket,

    # AWS Region of the bucket
    [Parameter()]
    [String]
    $Region,

    # Object name prefix filter
    [Parameter()]
    [String]
    $Prefix = [String]::Empty,

    # Object name prefix filter
    [Parameter()]
    [Switch]
    $Download = $False
)

$bucketUrl="https://s3.${Region}.amazonaws.com/${Bucket}/"
$bucketUrlWithPrefix="${bucketUrl}?prefix=${prefix}"

[xml]$data = Invoke-WebRequest $bucketUrlWithPrefix

Write-Verbose "Find the first $(($data.ListBucketResult.Contents.Key).Count) objects."

$Objects = @()
$Objects += $data.ListBucketResult.Contents

$i=1

While ($data.ListBucketResult.IsTruncated -eq "true") {
    Write-Verbose "Crawling page: $i"

    $lastItem = $Objects[-1].Key
    [xml]$data = Invoke-WebRequest -Uri "${bucketUrlWithPrefix}&marker=${lastItem}"
    $Objects += $data.ListBucketResult.Contents

    Write-Verbose "Total Objects: $($Objects.Count)"

    $i++
}

If ($Download) {

    Write-Verbose "Creating folder ${Bucket}"

    New-Item -Type Container "${Bucket}"

    ForEach ($Object in $Objects) {
        $objectKey = $Object.Key.Trim("\")
        $objectPath = Split-Path $objectKey

        If (!(Test-Path $objectPath)) {
            New-Item -Type Container "${Bucket}/${objectPath}"
        }

        Invoke-WebRequest -Uri "${bucketUrl}${objectKey}" -OutFile "${Bucket}/${objectKey}"
    }
}

$Objects