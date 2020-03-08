# WS8 Wavemeter to M Squared SolsTiS Laser Feedback
***[Bryce M. Henson](https://github.com/brycehenson), [Jacob A. Ross](https://github.com/GroundhogState)***    
**Status:** This Code is **working but messy inside**. Unit Testing is **not** implemented.

Uses software in the loop feedback of the optical frequency of a M Squared SolsTiS Laser (with doubler) to a WS8 wavemeter.
Checks if the laser has unlocked either the doubler or the Ti:Saf and relocks.
Can instigate an unlock of the doubler and a scan of the etalon.
Provides a detailed log file in JSON format.

| ![Feedback Demonstration](/figs/example_feedback.png "Fig1") | 
|:--:| 
| **Figure 1**- The program is able to perform low bandwith (~20Hz) feedback to the laser freqeuncy with excelent stability and range. |


## To Do
- [x] Nice picture
- [ ] Documentation
- [ ] move much of the code into functions
- [ ] move pid into separate project
  * build tests for pid
- [ ] clean up unused functions


## Contributions
This project would not have been possible without the many open source tools that it is based on.
* ***Jakko de Jong**** [WS6 or WS7 wavemeter driver](https://au.mathworks.com/matlabcentral/fileexchange/60330-ws6-or-ws7-wavemeter-driver)
* ***Todd Karin*** [solstislab](https://au.mathworks.com/matlabcentral/fileexchange/48669-solstislab?focused=3c86d3a6-ddfc-1192-89f5-24b4a08105ab&tab=function)
* ***Jakko de Jong**** [solstis class](https://au.mathworks.com/matlabcentral/fileexchange/60282-solstis-class?focused=b9c3d9cc-4c04-f794-f7ce-19688fc6d5ff&tab=function )
* ***Denis Gilbert***    [M-file Header Template](https://au.mathworks.com/matlabcentral/fileexchange/4908-m-file-header-template)

