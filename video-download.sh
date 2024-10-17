#!/bin/bash

# Define the target directory
#directory="/Volumes/6TB/Downloads/converted/test/inputs"
#directory="/Volumes/6TB/Downloads/converted/test/hold"


# Prompt the user to select a directory using Zenity
directory=$(zenity --file-selection --directory --title="Select a Directory")

# Check if the user selected a directory
if [ -z "$directory" ]; then
    echo "No directory selected."
else
    echo "You selected: $directory"
    # You can add further commands here to work with the selected directory
fi

# Check if the target is not a directory
if [ ! -d "$directory" ]; then
    echo "Error: $directory is not a valid directory."
    exit 1
fi


# Function to check if a file has a video extension
has_video_extension() {
    local FILE="$1"
    if [[ -f "$FILE" ]]; then
        # Convert filename to lowercase using tr
        LOWERCASE_FILE=$(echo "$FILE" | tr '[:upper:]' '[:lower:]')
        case "$LOWERCASE_FILE" in
            *.mp4|*.mkv|*.avi|*.mov|*.wmv|*.m4v|*.webm)
                echo "$FILE is likely a video file."
                ;;
            *)
                echo "$FILE is not recognized as a video file."
                rm $FILE
                ;;
        esac
    else
        echo "$FILE does not exist."
    fi
}



# Loop through each file in the directory
for FILE in "$directory"/*; do

    if [[ -f "$FILE" ]]; then   ##confirm this is a regular file and not a special file (hidden, etc)

        # Check if the file has an audio track using ffprobe which is a component of ffmpeg
        AUDIO_TRACKS=$(ffprobe -v error -select_streams a -show_entries stream=index -of csv=p=0 "$FILE")
    
        if [ -z "$AUDIO_TRACKS" ]; then
            echo "$FILE: has no audio track and will be deleted"
            rm "$FILE"    # Remove file if no audio track or it will cause ffmpeg error
        fi

    fi

done



# Change spaces to underscores in filenames
for file in "$directory"/*; do
    if [ -f "$file" ]; then
        new_name="${file// /_}"
        if [ "$new_name" != "$file" ]; then
            mv "$file" "$new_name"
            echo "Renamed: $file to $new_name"
        fi
    fi
done


result_string=""
counter=-1

# List the files in the target directory after renaming
#echo "Files in $directory:"
for file in "$directory"/*; do
    if [ -f "$file" ]; then
        #echo "$(basename "$file")"
        result_string+="$file -i "
        ((counter++))
    fi
done

# Trim the trailing space (optional)
result_string="${result_string% }"

#Print the resulting string
#echo "Concatenated string: $result_string"

# Print the final counter value
echo "Total files to process: $counter"


command_string+="/opt/homebrew/bin/ffmpeg -i $result_string"

# Replace the last three characters with a double quote
command_string="${command_string%??}-filter_complex \""

# Print the resulting string
#echo "Command string: $command_string"


parameter_string=""

for ((i=0; i<=counter; i++)); do
    #echo "Current number: $i"

    parameter_string+="[$i:v]scale=1280:720:force_original_aspect_ratio=1,pad=1280:720:(ow-iw)/2:(oh-ih)/2,setsar=1[v$i];"

done

# Print the resulting string
#echo "parameter string: $parameter_string"


command_string+="$parameter_string "

# Print the resulting string
#echo "Command string: $command_string"


for ((i=0; i<=counter; i++)); do

    parameter_stringv+="[v$i]"
    parameter_stringa+="[$i:a]"

done


parameter_stringv+="concat=n=$((counter + 1)):v=1:a=0[outv]; "
parameter_stringa+="concat=n=$((counter + 1)):v=0:a=1[outa]\" -map \"[outv]\" -map \"[outa]\" -loglevel debug "


# Print the resulting string
#echo "parameter stringa: $parameter_stringa"

# Get the current date and time in a specific format
current_date_time=$(date +"%Y-%m-%d_%H-%M-%S")

# Create a variable that includes the current date and time
output_file_name="output_$current_date_time.webm"

command_string+=$parameter_stringv$parameter_stringa$output_file_name

# Print the resulting string
echo $command_string

# Prompt the user for confirmation
read -p "Are you sure you want to execute this command? (y/n) [default: y]: " confirm

# Set default to 'y' if no input is provided
confirm=${confirm:-y}

# Check the user's response
if [[ "$confirm" =~ ^[yY]$ ]]; then
    # Execute the command using eval
    eval "$command_string"
else
    echo "Command not executed."
fi

