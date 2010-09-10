$(document).ready(function() {
  $(".sect .sect-title").each(function(i) {
    $(this).click(function() {
      $(this).next().toggle();
      $(this).toggleClass('undisclosed-title');
      $(this).toggleClass('disclosed-title');
      return false;
    });
    if ($(this).is(".undisclosed-title")) {
      $(this).next().hide();
    } else {
      $(this).next().show();
    }
  })
});

$(function() {
  var ontology_complete_url = application_root + '/ws/lookup/go/component/term/';

  $( "#ontology-term-entry" ).autocomplete({
    minLength: 2,
    source: ontology_complete_url,
    focus: function(event, ui) {
      $('#ontology-term-entry').val(ui.item.name);
      return false;
    },
    select: function(event, ui) {
      $('#ontology-term-entry').val(ui.item.name);
      return false;
    }
  })
  .data( "autocomplete" )._renderItem = function( ul, item ) {
    return $( "<li></li>" )
      .data( "item.autocomplete", item )
      .append( "<a>" + item.id + "<br>" + item.name + "</a>" )
      .appendTo( ul );
  };
});

