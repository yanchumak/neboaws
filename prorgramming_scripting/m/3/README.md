

Given 
```json
{
	"reservations": [
		{
			"instances": [
				{
					"name": "instance1",
					"state": "running",
					"reservationInYears": "2"
				},
				{
					"name": "instance2",
					"state": "stopped",
					"reservationInYears": "1"
				}
			]
		},
		{
			"instances": [
				{
					"name": "instance3",
					"state": "terminated",
					"reservationInYears": "3"
				},
				{
					"name": "instance4",
					"state": "running",
					"reservationInYears": "4"
				}
			]
		}
	]
}
```

Query
```json
{ "runningAndReservedUnder3Years": reservations[].instances[?state == 'running' && reservationInYears < `3`].name | [] }
```

Result
```json
{
  "runningAndReservedUnder3Years": [
    "instance1"
  ]
}
```
