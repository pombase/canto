$(document).ready(function() {
        $(".sect .sect-title").each(function(i) {
                $(this).click(function() {
                        $(this).next().toggle();
                        $(this).toggleClass('undisclosed-title');
                        $(this).toggleClass('disclosed-title');
                        return false;
                    }
                    );
                if ($(this).is(".undisclosed-title")) {
                    $(this).next().hide();
                } else {
                    $(this).next().show();
                }
            })
       });
