## cdm
Compact Discord Messages file format (.cdm)

> [!CAUTION]
> still in progress, things will change!

## what is it?
a .cdm file stores discord message data like content, user id, attachments and such  
note that this is NOT in human readable format, so you can't open it in a traditional text editor and read it

## why?
if you wanted to store/export discord messages and process them later using code or other tools, your only other option would have been storing them in JSON  

not only is JSON an objectively *bad* language but it is also inefficient in space and parsing  

imagine for example trying to encode image data using JSON, it would be a mess!  

so cdm solves this highly specific problem

## how does it work?
data in a .cdm file is highly compact and optimized, here is how it's done:
- not human readable but easily parsable
- using integers instead of bytes
- smart attachments
- keep the data you need
- no repetition

## how do i use it?
you can use cdm in 2 ways:
- to encode data into a .cdm file, which can be done manually or by converting from a .json file (exported from [DiscordChatExporter](https://github.com/Tyrrrz/DiscordChatExporter))
- to decode data from a .cdm file and use it for your needs

## what's in a cdm file?
to see what's in a .cdm file you would need to read one using a hex editor  

now in order to understand what's going on you would of course need to understand the cdm file format specification  

but since that's complex, you could understand it better using [ImHex](https://github.com/WerWolv/ImHex) and its pattern editor  

open a .cdm file using ImHex and open the pattern editor and paste everything from cdm/cdm.pat  

press F5 to refresh and you should see your beautiful color-coded data like this:  

![image](https://github.com/user-attachments/assets/d569145a-9e40-4405-ad27-de6d92d1b30d)
