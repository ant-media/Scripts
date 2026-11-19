<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta http-equiv="X-UA-Compatible" content="IE=edge">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Loading Example</title>
    <style>
        body {
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }

        #loading {
            display: flex;
            flex-direction: column;
            align-items: center;
            background: rgba(255, 255, 255, 0.8);
            border-radius: 10px;
            padding: 20px;
        }

        #loading img {
            width: 50px; /* Adjust the size of the loading indicator */
        }
    </style>
</head>
<body>

<div id="loading">
    <img src="loading.gif" alt="Loading..." />
    <p>Loading...</p>
</div>

<script>
    window.onload = function () {
        // Display the loading spinner
        document.getElementById("loading").style.display = "flex";

        // Make an asynchronous request to control-create.php
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "control-create.php", true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState == 4 && xhr.status == 200) {
                // Hide the loading spinner once control-create.php is executed
                document.getElementById("loading").style.display = "none";
		loadIndex2();
            }
        };
        xhr.send();
    };

    function loadIndex2() {
        // Make an asynchronous request to index-2.html
        var xhr = new XMLHttpRequest();
        xhr.open("GET", "index.html", true);
        xhr.onreadystatechange = function () {
            if (xhr.readyState == 4 && xhr.status == 200) {
                // Replace the current document content with index-2.html content
                document.open();
                document.write(xhr.responseText);
                document.close();
            }
        };
        xhr.send();
    }
</script>

</body>
</html>

